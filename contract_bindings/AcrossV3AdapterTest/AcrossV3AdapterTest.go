// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package AcrossV3AdapterTest

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

// AcrossV3AdapterTestMetaData contains all meta data concerning the AcrossV3AdapterTest contract.
var AcrossV3AdapterTestMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"receive\",\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"AAVE_BASE_WETH\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"AAVE_V4_BLOCK\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"AAVE_V4_CORE_HUB\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"AAVE_V4_MAIN_SPOKE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"AAVE_V4_USDC_RESERVE_ID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"AAVE_V4_USDT_RESERVE_ID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"AAVE_V4_WBTC_RESERVE_ID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"AAVE_V4_WETH_RESERVE_ID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"AAVE_V4_WSTETH_RESERVE_ID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"AAVE_VAULT_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ACCOUNT_COUNT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ACROSS_RELAYER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ACROSS_RELAYER_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ACROSS_V3_ADAPTER_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ACROSS_V3_HELPER_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ALOE_USDC_VAULT_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"APPROVE_AND_FLUID_STAKE_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"APPROVE_AND_SWAP_ALGEBRA_INTEGRAL_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"APPROVE_AND_SWAP_ODOSV2_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"APPROVE_AND_SWAP_OPENOCEAN_SPARKDEX_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"APPROVE_AND_SWAP_UNISWAP_V3_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"APPROVE_ERC20_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"APPROVE_WITH_PERMIT2_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"BANK_MANAGER_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"BASE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"BASE_BLOCK\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"BASE_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"BASE_RPC_URL_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"BATCH_TRANSFER_FROM_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CANCEL_REDEEM_REQUEST_7540_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CENTRIFUGE_USDC_VAULT_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_10_ALOE_USDC\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_10_DAI\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_10_NEXUS_BOOTSTRAP\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_10_NEXUS_FACTORY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_10_ODOS_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_10_PENDLE_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_10_PENDLE_SWAP\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_10_SPECTRA_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_10_SPOKE_POOL_V3_ADDRESS\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_10_USDC\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_10_USDCE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_10_WETH\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_AAVE_VAULT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_CENTRIFUGE_USDC\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_CUSDO\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_DAI\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_EULER_VAULT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_FLUID_VAULT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_GEAR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_GEARBOX_STAKING\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_GEARBOX_VAULT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_MORPHO_VAULT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_NEXUS_BOOTSTRAP\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_NEXUS_FACTORY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_ODOS_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_PENDLE_ETHENA\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_PENDLE_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_PENDLE_SWAP\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_SPECTRA_PTT_TOKEN\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_SPECTRA_PT_IPOR_USDC\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_SPECTRA_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_SPOKE_POOL_V3_ADDRESS\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_SUSDE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_USDC\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_USDE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_USDO\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_WBTC\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_WETH\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_WST_ETH\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_1_YEARN_VAULT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_AAVE_BASE_WETH\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_DAI\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_MORPHO_GAUNTLET_USDC_PRIME\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_MORPHO_GAUNTLET_WETH_CORE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_NEXUS_BOOTSTRAP\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_NEXUS_FACTORY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_ODOS_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_PENDLE_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_PENDLE_SWAP\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_SPARK_PSM3\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_SPARK_USDC_VAULT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_SPECTRA_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_SPOKE_POOL_V3_ADDRESS\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_SUPER_USDC_VAULT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_SUSDS\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_USDC\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_USDS\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_WETH\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_YO_BTC_VAULT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_YO_ETH_VAULT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CHAIN_8453_YO_USD_VAULT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DAI_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEBRIDGE_ADAPTER_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEBRIDGE_CANCEL_ORDER_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEBRIDGE_DLN_DST\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEBRIDGE_DLN_HELPER_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEBRIDGE_DLN_SOURCE_ADDRESS\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEBRIDGE_HELPER_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEPOSIT_4626_VAULT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEPOSIT_5115_VAULT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEPOSIT_7540_VAULT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ENTRYPOINT_ADDR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ERC1155_LEDGER_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ERC4626_VAULT_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ERC4626_YIELD_SOURCE_ORACLE_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ERC5115_VAULT_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ERC5115_YIELD_SOURCE_ORACLE_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ERC7540_FULLY_ASYNC_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ERC7540_YIELD_SOURCE_ORACLE_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ETH\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ETHENA_COOLDOWN_SHARES_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ETHENA_UNSTAKE_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ETHEREUM_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ETHEREUM_RPC_URL_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ETH_BLOCK\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"EULER_VAULT_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"EXTRA_LARGE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FEE_RECIPIENT_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FLARE_ALGEBRA_INTEGRAL_SWAP_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FLARE_ALGEBRA_POOL_DEPLOYER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FLARE_RNAT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FLARE_SFLR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FLARE_SPRK\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FLARE_WFLR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FLUID_CLAIM_REWARD_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FLUID_STAKE_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FLUID_UNSTAKE_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"FLUID_VAULT_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"GEARBOX_APPROVE_AND_STAKE_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"GEARBOX_CLAIM_REWARD_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"GEARBOX_STAKE_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"GEARBOX_STAKING_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"GEARBOX_UNSTAKE_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"GEARBOX_VAULT_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"GEAR_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"IS_TEST\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"LARGE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MAINNET_V2_SWAP_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MAINNET_V3_SWAP_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MAINNET_V3_SWAP_ROUTER_02\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MAINNET_V4_POOL_MANAGER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MAINNET_V4_POSITION_MANAGER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MANAGER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MANAGER_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MARK_ROOT_AS_USED_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MEDIUM\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MERKL_CLAIM_REWARD_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MERKL_DISTRIBUTOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MINT_SUPERPOSITIONS_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MOCK_APPROVE_AND_SWAP_ODOS_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MOCK_SWAP_ODOS_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MOCK_TARGET_EXECUTOR_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MORPHO\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MORPHO_BORROW_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MORPHO_GAUNTLET_USDC_PRIME_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MORPHO_GAUNTLET_WETH_CORE_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MORPHO_IRM\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MORPHO_IRM_WBTC_USDC\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MORPHO_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MORPHO_ORACLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MORPHO_ORACLE_WBTC_USDC\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MORPHO_REPAY_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"MORPHO_VAULT_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"NEXUS_ACCOUNT_IMPLEMENTATION_ID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ODOS_ROUTER_V3\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"OFFRAMP_TOKENS_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ONE_INCH_API_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ONE_INCH_ROUTER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"OP\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"OPTIMISM_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"OPTIMISM_RPC_URL_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"OP_BLOCK\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"PENDLE_ETHENA_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"PENDLE_ROUTER_REDEEM_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"PENDLE_ROUTER_SWAP_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"PERMIT2\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"PERMIT_WITH_PERMIT2_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"REDEEM_4626_VAULT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"REDEEM_5115_VAULT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"REDEEM_7540_VAULT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"REQUEST_REDEEM_7540_VAULT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ROLES_ID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SAFE_REGISTRY_ADDR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SMALL\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SOMELIER_STAKE_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SOMELIER_UNBOND_ALL_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SOMELIER_UNBOND_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SOMELIER_UNSTAKE_ALL_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SOMELIER_UNSTAKE_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SPARK_USDC_VAULT_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SPECTRA_EXCHANGE_DEPOSIT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SPECTRA_EXCHANGE_REDEEM_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"STAKING_YIELD_SOURCE_ORACLE_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"STRATEGIST_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_7702_SENDER_CREATOR_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_BUNDLER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_BUNDLER_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_COLLECTIVE_VAULT_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_DESTINATION_EXECUTOR_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_DESTINATION_VALIDATOR_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_EXECUTOR_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_GAS_TANK_ID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_LEDGER_CONFIGURATION_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_LEDGER_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_MERKLE_VALIDATOR_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_NATIVE_PAYMASTER_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_SENDER_CREATOR_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUSDE_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SWAP_1INCH_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SWAP_ALGEBRA_INTEGRAL_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SWAP_ODOSV2_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SWAP_OPENOCEAN_SPARKDEX_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SWAP_UNISWAP_V3_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SWAP_UNISWAP_V4_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SWAP_UNISWAP_V4_MULTI_HOP_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"TRANSFER_ERC20_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"TREASURY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"TREASURY_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"USDCE_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"USDC_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"USDE_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"USER1_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"USER2_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"VALIDATOR_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"WETH_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"WITHDRAW_7540_VAULT_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"WST_ETH_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"YEARN_CLAIM_ALL_REWARDS_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"YEARN_CLAIM_ONE_REWARD_HOOK_KEY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"acrossV3Adapter\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractAcrossV3Adapter\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"debridgeAdapter\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractDebridgeAdapter\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"deployAccounts\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"envOr\",\"inputs\":[{\"name\":\"name\",\"type\":\"string\",\"internalType\":\"string\"},{\"name\":\"defaultValue\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"value\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"envOr\",\"inputs\":[{\"name\":\"name\",\"type\":\"string\",\"internalType\":\"string\"},{\"name\":\"defaultValue\",\"type\":\"string\",\"internalType\":\"string\"}],\"outputs\":[{\"name\":\"value\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"excludeArtifacts\",\"inputs\":[],\"outputs\":[{\"name\":\"excludedArtifacts_\",\"type\":\"string[]\",\"internalType\":\"string[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"excludeContracts\",\"inputs\":[],\"outputs\":[{\"name\":\"excludedContracts_\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"excludeSelectors\",\"inputs\":[],\"outputs\":[{\"name\":\"excludedSelectors_\",\"type\":\"tuple[]\",\"internalType\":\"structStdInvariant.FuzzSelector[]\",\"components\":[{\"name\":\"addr\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"selectors\",\"type\":\"bytes4[]\",\"internalType\":\"bytes4[]\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"excludeSenders\",\"inputs\":[],\"outputs\":[{\"name\":\"excludedSenders_\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"failed\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"mockDlnDestination\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractMockDlnDestination\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"mockERC20\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractMockERC20\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"processBridgedExecution\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"setUp\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"startStateDiffRecording\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"targetArtifactSelectors\",\"inputs\":[],\"outputs\":[{\"name\":\"targetedArtifactSelectors_\",\"type\":\"tuple[]\",\"internalType\":\"structStdInvariant.FuzzArtifactSelector[]\",\"components\":[{\"name\":\"artifact\",\"type\":\"string\",\"internalType\":\"string\"},{\"name\":\"selectors\",\"type\":\"bytes4[]\",\"internalType\":\"bytes4[]\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"targetArtifacts\",\"inputs\":[],\"outputs\":[{\"name\":\"targetedArtifacts_\",\"type\":\"string[]\",\"internalType\":\"string[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"targetContracts\",\"inputs\":[],\"outputs\":[{\"name\":\"targetedContracts_\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"targetInterfaces\",\"inputs\":[],\"outputs\":[{\"name\":\"targetedInterfaces_\",\"type\":\"tuple[]\",\"internalType\":\"structStdInvariant.FuzzInterface[]\",\"components\":[{\"name\":\"addr\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"artifacts\",\"type\":\"string[]\",\"internalType\":\"string[]\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"targetSelectors\",\"inputs\":[],\"outputs\":[{\"name\":\"targetedSelectors_\",\"type\":\"tuple[]\",\"internalType\":\"structStdInvariant.FuzzSelector[]\",\"components\":[{\"name\":\"addr\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"selectors\",\"type\":\"bytes4[]\",\"internalType\":\"bytes4[]\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"targetSenders\",\"inputs\":[],\"outputs\":[{\"name\":\"targetedSenders_\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"test_Constructor\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_Debridge_Constructor\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_Debridge_HandleERC20\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_Debridge_HandleEth\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_Debridge_InvalidDecoding\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_Debridge_InvalidEthRecipient\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_Debridge_InvalidSender\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_Debridge_InvalidToken\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_Handle\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_InvalidDecoding\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_InvalidSender\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"test_InvalidToken\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"user1\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"user2\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"user3\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"SlotFound\",\"inputs\":[{\"name\":\"who\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"fsig\",\"type\":\"bytes4\",\"indexed\":false,\"internalType\":\"bytes4\"},{\"name\":\"keysHash\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"slot\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"WARNING_UninitedSlot\",\"inputs\":[{\"name\":\"who\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"slot\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log\",\"inputs\":[{\"name\":\"\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_address\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_array\",\"inputs\":[{\"name\":\"val\",\"type\":\"uint256[]\",\"indexed\":false,\"internalType\":\"uint256[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_array\",\"inputs\":[{\"name\":\"val\",\"type\":\"int256[]\",\"indexed\":false,\"internalType\":\"int256[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_array\",\"inputs\":[{\"name\":\"val\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_bytes\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"indexed\":false,\"internalType\":\"bytes\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_bytes32\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_int\",\"inputs\":[{\"name\":\"\",\"type\":\"int256\",\"indexed\":false,\"internalType\":\"int256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_named_address\",\"inputs\":[{\"name\":\"key\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"val\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_named_array\",\"inputs\":[{\"name\":\"key\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"val\",\"type\":\"uint256[]\",\"indexed\":false,\"internalType\":\"uint256[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_named_array\",\"inputs\":[{\"name\":\"key\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"val\",\"type\":\"int256[]\",\"indexed\":false,\"internalType\":\"int256[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_named_array\",\"inputs\":[{\"name\":\"key\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"val\",\"type\":\"address[]\",\"indexed\":false,\"internalType\":\"address[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_named_bytes\",\"inputs\":[{\"name\":\"key\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"val\",\"type\":\"bytes\",\"indexed\":false,\"internalType\":\"bytes\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_named_bytes32\",\"inputs\":[{\"name\":\"key\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"val\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_named_decimal_int\",\"inputs\":[{\"name\":\"key\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"val\",\"type\":\"int256\",\"indexed\":false,\"internalType\":\"int256\"},{\"name\":\"decimals\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_named_decimal_uint\",\"inputs\":[{\"name\":\"key\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"val\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"decimals\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_named_int\",\"inputs\":[{\"name\":\"key\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"val\",\"type\":\"int256\",\"indexed\":false,\"internalType\":\"int256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_named_string\",\"inputs\":[{\"name\":\"key\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"val\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_named_uint\",\"inputs\":[{\"name\":\"key\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"val\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_string\",\"inputs\":[{\"name\":\"\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"log_uint\",\"inputs\":[{\"name\":\"\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"logs\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"indexed\":false,\"internalType\":\"bytes\"}],\"anonymous\":false}]",
}

// AcrossV3AdapterTestABI is the input ABI used to generate the binding from.
// Deprecated: Use AcrossV3AdapterTestMetaData.ABI instead.
var AcrossV3AdapterTestABI = AcrossV3AdapterTestMetaData.ABI

// AcrossV3AdapterTest is an auto generated Go binding around an Ethereum contract.
type AcrossV3AdapterTest struct {
	AcrossV3AdapterTestCaller     // Read-only binding to the contract
	AcrossV3AdapterTestTransactor // Write-only binding to the contract
	AcrossV3AdapterTestFilterer   // Log filterer for contract events
}

// AcrossV3AdapterTestCaller is an auto generated read-only Go binding around an Ethereum contract.
type AcrossV3AdapterTestCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AcrossV3AdapterTestTransactor is an auto generated write-only Go binding around an Ethereum contract.
type AcrossV3AdapterTestTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AcrossV3AdapterTestFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type AcrossV3AdapterTestFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AcrossV3AdapterTestSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type AcrossV3AdapterTestSession struct {
	Contract     *AcrossV3AdapterTest // Generic contract binding to set the session for
	CallOpts     bind.CallOpts        // Call options to use throughout this session
	TransactOpts bind.TransactOpts    // Transaction auth options to use throughout this session
}

// AcrossV3AdapterTestCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type AcrossV3AdapterTestCallerSession struct {
	Contract *AcrossV3AdapterTestCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts              // Call options to use throughout this session
}

// AcrossV3AdapterTestTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type AcrossV3AdapterTestTransactorSession struct {
	Contract     *AcrossV3AdapterTestTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts              // Transaction auth options to use throughout this session
}

// AcrossV3AdapterTestRaw is an auto generated low-level Go binding around an Ethereum contract.
type AcrossV3AdapterTestRaw struct {
	Contract *AcrossV3AdapterTest // Generic contract binding to access the raw methods on
}

// AcrossV3AdapterTestCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type AcrossV3AdapterTestCallerRaw struct {
	Contract *AcrossV3AdapterTestCaller // Generic read-only contract binding to access the raw methods on
}

// AcrossV3AdapterTestTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type AcrossV3AdapterTestTransactorRaw struct {
	Contract *AcrossV3AdapterTestTransactor // Generic write-only contract binding to access the raw methods on
}

// NewAcrossV3AdapterTest creates a new instance of AcrossV3AdapterTest, bound to a specific deployed contract.
func NewAcrossV3AdapterTest(address common.Address, backend bind.ContractBackend) (*AcrossV3AdapterTest, error) {
	contract, err := bindAcrossV3AdapterTest(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTest{AcrossV3AdapterTestCaller: AcrossV3AdapterTestCaller{contract: contract}, AcrossV3AdapterTestTransactor: AcrossV3AdapterTestTransactor{contract: contract}, AcrossV3AdapterTestFilterer: AcrossV3AdapterTestFilterer{contract: contract}}, nil
}

// NewAcrossV3AdapterTestCaller creates a new read-only instance of AcrossV3AdapterTest, bound to a specific deployed contract.
func NewAcrossV3AdapterTestCaller(address common.Address, caller bind.ContractCaller) (*AcrossV3AdapterTestCaller, error) {
	contract, err := bindAcrossV3AdapterTest(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestCaller{contract: contract}, nil
}

// NewAcrossV3AdapterTestTransactor creates a new write-only instance of AcrossV3AdapterTest, bound to a specific deployed contract.
func NewAcrossV3AdapterTestTransactor(address common.Address, transactor bind.ContractTransactor) (*AcrossV3AdapterTestTransactor, error) {
	contract, err := bindAcrossV3AdapterTest(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestTransactor{contract: contract}, nil
}

// NewAcrossV3AdapterTestFilterer creates a new log filterer instance of AcrossV3AdapterTest, bound to a specific deployed contract.
func NewAcrossV3AdapterTestFilterer(address common.Address, filterer bind.ContractFilterer) (*AcrossV3AdapterTestFilterer, error) {
	contract, err := bindAcrossV3AdapterTest(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestFilterer{contract: contract}, nil
}

// bindAcrossV3AdapterTest binds a generic wrapper to an already deployed contract.
func bindAcrossV3AdapterTest(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := AcrossV3AdapterTestMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_AcrossV3AdapterTest *AcrossV3AdapterTestRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _AcrossV3AdapterTest.Contract.AcrossV3AdapterTestCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_AcrossV3AdapterTest *AcrossV3AdapterTestRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.AcrossV3AdapterTestTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_AcrossV3AdapterTest *AcrossV3AdapterTestRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.AcrossV3AdapterTestTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _AcrossV3AdapterTest.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.contract.Transact(opts, method, params...)
}

// AAVEBASEWETH is a free data retrieval call binding the contract method 0x0f5a0790.
//
// Solidity: function AAVE_BASE_WETH() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) AAVEBASEWETH(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "AAVE_BASE_WETH")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// AAVEBASEWETH is a free data retrieval call binding the contract method 0x0f5a0790.
//
// Solidity: function AAVE_BASE_WETH() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) AAVEBASEWETH() (string, error) {
	return _AcrossV3AdapterTest.Contract.AAVEBASEWETH(&_AcrossV3AdapterTest.CallOpts)
}

// AAVEBASEWETH is a free data retrieval call binding the contract method 0x0f5a0790.
//
// Solidity: function AAVE_BASE_WETH() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) AAVEBASEWETH() (string, error) {
	return _AcrossV3AdapterTest.Contract.AAVEBASEWETH(&_AcrossV3AdapterTest.CallOpts)
}

// AAVEV4BLOCK is a free data retrieval call binding the contract method 0x10b7dd31.
//
// Solidity: function AAVE_V4_BLOCK() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) AAVEV4BLOCK(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "AAVE_V4_BLOCK")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// AAVEV4BLOCK is a free data retrieval call binding the contract method 0x10b7dd31.
//
// Solidity: function AAVE_V4_BLOCK() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) AAVEV4BLOCK() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.AAVEV4BLOCK(&_AcrossV3AdapterTest.CallOpts)
}

// AAVEV4BLOCK is a free data retrieval call binding the contract method 0x10b7dd31.
//
// Solidity: function AAVE_V4_BLOCK() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) AAVEV4BLOCK() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.AAVEV4BLOCK(&_AcrossV3AdapterTest.CallOpts)
}

// AAVEV4COREHUB is a free data retrieval call binding the contract method 0x1bcf118c.
//
// Solidity: function AAVE_V4_CORE_HUB() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) AAVEV4COREHUB(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "AAVE_V4_CORE_HUB")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AAVEV4COREHUB is a free data retrieval call binding the contract method 0x1bcf118c.
//
// Solidity: function AAVE_V4_CORE_HUB() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) AAVEV4COREHUB() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.AAVEV4COREHUB(&_AcrossV3AdapterTest.CallOpts)
}

// AAVEV4COREHUB is a free data retrieval call binding the contract method 0x1bcf118c.
//
// Solidity: function AAVE_V4_CORE_HUB() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) AAVEV4COREHUB() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.AAVEV4COREHUB(&_AcrossV3AdapterTest.CallOpts)
}

// AAVEV4MAINSPOKE is a free data retrieval call binding the contract method 0xe6604638.
//
// Solidity: function AAVE_V4_MAIN_SPOKE() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) AAVEV4MAINSPOKE(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "AAVE_V4_MAIN_SPOKE")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AAVEV4MAINSPOKE is a free data retrieval call binding the contract method 0xe6604638.
//
// Solidity: function AAVE_V4_MAIN_SPOKE() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) AAVEV4MAINSPOKE() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.AAVEV4MAINSPOKE(&_AcrossV3AdapterTest.CallOpts)
}

// AAVEV4MAINSPOKE is a free data retrieval call binding the contract method 0xe6604638.
//
// Solidity: function AAVE_V4_MAIN_SPOKE() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) AAVEV4MAINSPOKE() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.AAVEV4MAINSPOKE(&_AcrossV3AdapterTest.CallOpts)
}

// AAVEV4USDCRESERVEID is a free data retrieval call binding the contract method 0xe61675eb.
//
// Solidity: function AAVE_V4_USDC_RESERVE_ID() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) AAVEV4USDCRESERVEID(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "AAVE_V4_USDC_RESERVE_ID")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// AAVEV4USDCRESERVEID is a free data retrieval call binding the contract method 0xe61675eb.
//
// Solidity: function AAVE_V4_USDC_RESERVE_ID() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) AAVEV4USDCRESERVEID() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.AAVEV4USDCRESERVEID(&_AcrossV3AdapterTest.CallOpts)
}

// AAVEV4USDCRESERVEID is a free data retrieval call binding the contract method 0xe61675eb.
//
// Solidity: function AAVE_V4_USDC_RESERVE_ID() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) AAVEV4USDCRESERVEID() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.AAVEV4USDCRESERVEID(&_AcrossV3AdapterTest.CallOpts)
}

// AAVEV4USDTRESERVEID is a free data retrieval call binding the contract method 0xfc2ba9e0.
//
// Solidity: function AAVE_V4_USDT_RESERVE_ID() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) AAVEV4USDTRESERVEID(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "AAVE_V4_USDT_RESERVE_ID")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// AAVEV4USDTRESERVEID is a free data retrieval call binding the contract method 0xfc2ba9e0.
//
// Solidity: function AAVE_V4_USDT_RESERVE_ID() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) AAVEV4USDTRESERVEID() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.AAVEV4USDTRESERVEID(&_AcrossV3AdapterTest.CallOpts)
}

// AAVEV4USDTRESERVEID is a free data retrieval call binding the contract method 0xfc2ba9e0.
//
// Solidity: function AAVE_V4_USDT_RESERVE_ID() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) AAVEV4USDTRESERVEID() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.AAVEV4USDTRESERVEID(&_AcrossV3AdapterTest.CallOpts)
}

// AAVEV4WBTCRESERVEID is a free data retrieval call binding the contract method 0xe51d6ffa.
//
// Solidity: function AAVE_V4_WBTC_RESERVE_ID() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) AAVEV4WBTCRESERVEID(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "AAVE_V4_WBTC_RESERVE_ID")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// AAVEV4WBTCRESERVEID is a free data retrieval call binding the contract method 0xe51d6ffa.
//
// Solidity: function AAVE_V4_WBTC_RESERVE_ID() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) AAVEV4WBTCRESERVEID() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.AAVEV4WBTCRESERVEID(&_AcrossV3AdapterTest.CallOpts)
}

// AAVEV4WBTCRESERVEID is a free data retrieval call binding the contract method 0xe51d6ffa.
//
// Solidity: function AAVE_V4_WBTC_RESERVE_ID() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) AAVEV4WBTCRESERVEID() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.AAVEV4WBTCRESERVEID(&_AcrossV3AdapterTest.CallOpts)
}

// AAVEV4WETHRESERVEID is a free data retrieval call binding the contract method 0xbcbd020f.
//
// Solidity: function AAVE_V4_WETH_RESERVE_ID() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) AAVEV4WETHRESERVEID(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "AAVE_V4_WETH_RESERVE_ID")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// AAVEV4WETHRESERVEID is a free data retrieval call binding the contract method 0xbcbd020f.
//
// Solidity: function AAVE_V4_WETH_RESERVE_ID() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) AAVEV4WETHRESERVEID() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.AAVEV4WETHRESERVEID(&_AcrossV3AdapterTest.CallOpts)
}

// AAVEV4WETHRESERVEID is a free data retrieval call binding the contract method 0xbcbd020f.
//
// Solidity: function AAVE_V4_WETH_RESERVE_ID() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) AAVEV4WETHRESERVEID() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.AAVEV4WETHRESERVEID(&_AcrossV3AdapterTest.CallOpts)
}

// AAVEV4WSTETHRESERVEID is a free data retrieval call binding the contract method 0x120d0a37.
//
// Solidity: function AAVE_V4_WSTETH_RESERVE_ID() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) AAVEV4WSTETHRESERVEID(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "AAVE_V4_WSTETH_RESERVE_ID")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// AAVEV4WSTETHRESERVEID is a free data retrieval call binding the contract method 0x120d0a37.
//
// Solidity: function AAVE_V4_WSTETH_RESERVE_ID() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) AAVEV4WSTETHRESERVEID() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.AAVEV4WSTETHRESERVEID(&_AcrossV3AdapterTest.CallOpts)
}

// AAVEV4WSTETHRESERVEID is a free data retrieval call binding the contract method 0x120d0a37.
//
// Solidity: function AAVE_V4_WSTETH_RESERVE_ID() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) AAVEV4WSTETHRESERVEID() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.AAVEV4WSTETHRESERVEID(&_AcrossV3AdapterTest.CallOpts)
}

// AAVEVAULTKEY is a free data retrieval call binding the contract method 0x93e98002.
//
// Solidity: function AAVE_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) AAVEVAULTKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "AAVE_VAULT_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// AAVEVAULTKEY is a free data retrieval call binding the contract method 0x93e98002.
//
// Solidity: function AAVE_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) AAVEVAULTKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.AAVEVAULTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// AAVEVAULTKEY is a free data retrieval call binding the contract method 0x93e98002.
//
// Solidity: function AAVE_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) AAVEVAULTKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.AAVEVAULTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ACCOUNTCOUNT is a free data retrieval call binding the contract method 0x14475517.
//
// Solidity: function ACCOUNT_COUNT() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ACCOUNTCOUNT(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ACCOUNT_COUNT")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// ACCOUNTCOUNT is a free data retrieval call binding the contract method 0x14475517.
//
// Solidity: function ACCOUNT_COUNT() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ACCOUNTCOUNT() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.ACCOUNTCOUNT(&_AcrossV3AdapterTest.CallOpts)
}

// ACCOUNTCOUNT is a free data retrieval call binding the contract method 0x14475517.
//
// Solidity: function ACCOUNT_COUNT() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ACCOUNTCOUNT() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.ACCOUNTCOUNT(&_AcrossV3AdapterTest.CallOpts)
}

// ACROSSRELAYER is a free data retrieval call binding the contract method 0xf50b6fad.
//
// Solidity: function ACROSS_RELAYER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ACROSSRELAYER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ACROSS_RELAYER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// ACROSSRELAYER is a free data retrieval call binding the contract method 0xf50b6fad.
//
// Solidity: function ACROSS_RELAYER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ACROSSRELAYER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.ACROSSRELAYER(&_AcrossV3AdapterTest.CallOpts)
}

// ACROSSRELAYER is a free data retrieval call binding the contract method 0xf50b6fad.
//
// Solidity: function ACROSS_RELAYER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ACROSSRELAYER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.ACROSSRELAYER(&_AcrossV3AdapterTest.CallOpts)
}

// ACROSSRELAYERKEY is a free data retrieval call binding the contract method 0x90d93a58.
//
// Solidity: function ACROSS_RELAYER_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ACROSSRELAYERKEY(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ACROSS_RELAYER_KEY")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// ACROSSRELAYERKEY is a free data retrieval call binding the contract method 0x90d93a58.
//
// Solidity: function ACROSS_RELAYER_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ACROSSRELAYERKEY() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.ACROSSRELAYERKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ACROSSRELAYERKEY is a free data retrieval call binding the contract method 0x90d93a58.
//
// Solidity: function ACROSS_RELAYER_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ACROSSRELAYERKEY() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.ACROSSRELAYERKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY is a free data retrieval call binding the contract method 0x378ee239.
//
// Solidity: function ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY is a free data retrieval call binding the contract method 0x378ee239.
//
// Solidity: function ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY is a free data retrieval call binding the contract method 0x378ee239.
//
// Solidity: function ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ACROSSV3ADAPTERKEY is a free data retrieval call binding the contract method 0xfdf58f7e.
//
// Solidity: function ACROSS_V3_ADAPTER_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ACROSSV3ADAPTERKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ACROSS_V3_ADAPTER_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ACROSSV3ADAPTERKEY is a free data retrieval call binding the contract method 0xfdf58f7e.
//
// Solidity: function ACROSS_V3_ADAPTER_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ACROSSV3ADAPTERKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ACROSSV3ADAPTERKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ACROSSV3ADAPTERKEY is a free data retrieval call binding the contract method 0xfdf58f7e.
//
// Solidity: function ACROSS_V3_ADAPTER_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ACROSSV3ADAPTERKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ACROSSV3ADAPTERKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ACROSSV3HELPERKEY is a free data retrieval call binding the contract method 0x7561a70f.
//
// Solidity: function ACROSS_V3_HELPER_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ACROSSV3HELPERKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ACROSS_V3_HELPER_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ACROSSV3HELPERKEY is a free data retrieval call binding the contract method 0x7561a70f.
//
// Solidity: function ACROSS_V3_HELPER_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ACROSSV3HELPERKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ACROSSV3HELPERKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ACROSSV3HELPERKEY is a free data retrieval call binding the contract method 0x7561a70f.
//
// Solidity: function ACROSS_V3_HELPER_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ACROSSV3HELPERKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ACROSSV3HELPERKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ALOEUSDCVAULTKEY is a free data retrieval call binding the contract method 0xb8335821.
//
// Solidity: function ALOE_USDC_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ALOEUSDCVAULTKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ALOE_USDC_VAULT_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ALOEUSDCVAULTKEY is a free data retrieval call binding the contract method 0xb8335821.
//
// Solidity: function ALOE_USDC_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ALOEUSDCVAULTKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ALOEUSDCVAULTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ALOEUSDCVAULTKEY is a free data retrieval call binding the contract method 0xb8335821.
//
// Solidity: function ALOE_USDC_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ALOEUSDCVAULTKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ALOEUSDCVAULTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// APPROVEANDACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY is a free data retrieval call binding the contract method 0x116b016b.
//
// Solidity: function APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) APPROVEANDACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// APPROVEANDACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY is a free data retrieval call binding the contract method 0x116b016b.
//
// Solidity: function APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) APPROVEANDACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.APPROVEANDACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// APPROVEANDACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY is a free data retrieval call binding the contract method 0x116b016b.
//
// Solidity: function APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) APPROVEANDACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.APPROVEANDACROSSSENDFUNDSANDEXECUTEONDSTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// APPROVEANDDEPOSIT4626VAULTHOOKKEY is a free data retrieval call binding the contract method 0x357ceba9.
//
// Solidity: function APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) APPROVEANDDEPOSIT4626VAULTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// APPROVEANDDEPOSIT4626VAULTHOOKKEY is a free data retrieval call binding the contract method 0x357ceba9.
//
// Solidity: function APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) APPROVEANDDEPOSIT4626VAULTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.APPROVEANDDEPOSIT4626VAULTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// APPROVEANDDEPOSIT4626VAULTHOOKKEY is a free data retrieval call binding the contract method 0x357ceba9.
//
// Solidity: function APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) APPROVEANDDEPOSIT4626VAULTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.APPROVEANDDEPOSIT4626VAULTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// APPROVEANDDEPOSIT5115VAULTHOOKKEY is a free data retrieval call binding the contract method 0x8496a0c6.
//
// Solidity: function APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) APPROVEANDDEPOSIT5115VAULTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// APPROVEANDDEPOSIT5115VAULTHOOKKEY is a free data retrieval call binding the contract method 0x8496a0c6.
//
// Solidity: function APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) APPROVEANDDEPOSIT5115VAULTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.APPROVEANDDEPOSIT5115VAULTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// APPROVEANDDEPOSIT5115VAULTHOOKKEY is a free data retrieval call binding the contract method 0x8496a0c6.
//
// Solidity: function APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) APPROVEANDDEPOSIT5115VAULTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.APPROVEANDDEPOSIT5115VAULTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// APPROVEANDFLUIDSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xdccd7728.
//
// Solidity: function APPROVE_AND_FLUID_STAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) APPROVEANDFLUIDSTAKEHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "APPROVE_AND_FLUID_STAKE_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// APPROVEANDFLUIDSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xdccd7728.
//
// Solidity: function APPROVE_AND_FLUID_STAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) APPROVEANDFLUIDSTAKEHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.APPROVEANDFLUIDSTAKEHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// APPROVEANDFLUIDSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xdccd7728.
//
// Solidity: function APPROVE_AND_FLUID_STAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) APPROVEANDFLUIDSTAKEHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.APPROVEANDFLUIDSTAKEHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// APPROVEANDREQUESTDEPOSIT7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x8807e778.
//
// Solidity: function APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) APPROVEANDREQUESTDEPOSIT7540VAULTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// APPROVEANDREQUESTDEPOSIT7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x8807e778.
//
// Solidity: function APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) APPROVEANDREQUESTDEPOSIT7540VAULTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.APPROVEANDREQUESTDEPOSIT7540VAULTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// APPROVEANDREQUESTDEPOSIT7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x8807e778.
//
// Solidity: function APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) APPROVEANDREQUESTDEPOSIT7540VAULTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.APPROVEANDREQUESTDEPOSIT7540VAULTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// APPROVEANDSWAPALGEBRAINTEGRALHOOKKEY is a free data retrieval call binding the contract method 0x36851f78.
//
// Solidity: function APPROVE_AND_SWAP_ALGEBRA_INTEGRAL_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) APPROVEANDSWAPALGEBRAINTEGRALHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "APPROVE_AND_SWAP_ALGEBRA_INTEGRAL_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// APPROVEANDSWAPALGEBRAINTEGRALHOOKKEY is a free data retrieval call binding the contract method 0x36851f78.
//
// Solidity: function APPROVE_AND_SWAP_ALGEBRA_INTEGRAL_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) APPROVEANDSWAPALGEBRAINTEGRALHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.APPROVEANDSWAPALGEBRAINTEGRALHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// APPROVEANDSWAPALGEBRAINTEGRALHOOKKEY is a free data retrieval call binding the contract method 0x36851f78.
//
// Solidity: function APPROVE_AND_SWAP_ALGEBRA_INTEGRAL_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) APPROVEANDSWAPALGEBRAINTEGRALHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.APPROVEANDSWAPALGEBRAINTEGRALHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// APPROVEANDSWAPODOSV2HOOKKEY is a free data retrieval call binding the contract method 0x57e9ee36.
//
// Solidity: function APPROVE_AND_SWAP_ODOSV2_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) APPROVEANDSWAPODOSV2HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "APPROVE_AND_SWAP_ODOSV2_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// APPROVEANDSWAPODOSV2HOOKKEY is a free data retrieval call binding the contract method 0x57e9ee36.
//
// Solidity: function APPROVE_AND_SWAP_ODOSV2_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) APPROVEANDSWAPODOSV2HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.APPROVEANDSWAPODOSV2HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// APPROVEANDSWAPODOSV2HOOKKEY is a free data retrieval call binding the contract method 0x57e9ee36.
//
// Solidity: function APPROVE_AND_SWAP_ODOSV2_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) APPROVEANDSWAPODOSV2HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.APPROVEANDSWAPODOSV2HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// APPROVEANDSWAPOPENOCEANSPARKDEXHOOKKEY is a free data retrieval call binding the contract method 0xeaf33f2c.
//
// Solidity: function APPROVE_AND_SWAP_OPENOCEAN_SPARKDEX_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) APPROVEANDSWAPOPENOCEANSPARKDEXHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "APPROVE_AND_SWAP_OPENOCEAN_SPARKDEX_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// APPROVEANDSWAPOPENOCEANSPARKDEXHOOKKEY is a free data retrieval call binding the contract method 0xeaf33f2c.
//
// Solidity: function APPROVE_AND_SWAP_OPENOCEAN_SPARKDEX_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) APPROVEANDSWAPOPENOCEANSPARKDEXHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.APPROVEANDSWAPOPENOCEANSPARKDEXHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// APPROVEANDSWAPOPENOCEANSPARKDEXHOOKKEY is a free data retrieval call binding the contract method 0xeaf33f2c.
//
// Solidity: function APPROVE_AND_SWAP_OPENOCEAN_SPARKDEX_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) APPROVEANDSWAPOPENOCEANSPARKDEXHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.APPROVEANDSWAPOPENOCEANSPARKDEXHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// APPROVEANDSWAPUNISWAPV3HOOKKEY is a free data retrieval call binding the contract method 0x0c3c3c64.
//
// Solidity: function APPROVE_AND_SWAP_UNISWAP_V3_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) APPROVEANDSWAPUNISWAPV3HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "APPROVE_AND_SWAP_UNISWAP_V3_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// APPROVEANDSWAPUNISWAPV3HOOKKEY is a free data retrieval call binding the contract method 0x0c3c3c64.
//
// Solidity: function APPROVE_AND_SWAP_UNISWAP_V3_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) APPROVEANDSWAPUNISWAPV3HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.APPROVEANDSWAPUNISWAPV3HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// APPROVEANDSWAPUNISWAPV3HOOKKEY is a free data retrieval call binding the contract method 0x0c3c3c64.
//
// Solidity: function APPROVE_AND_SWAP_UNISWAP_V3_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) APPROVEANDSWAPUNISWAPV3HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.APPROVEANDSWAPUNISWAPV3HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// APPROVEERC20HOOKKEY is a free data retrieval call binding the contract method 0x6aa8f025.
//
// Solidity: function APPROVE_ERC20_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) APPROVEERC20HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "APPROVE_ERC20_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// APPROVEERC20HOOKKEY is a free data retrieval call binding the contract method 0x6aa8f025.
//
// Solidity: function APPROVE_ERC20_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) APPROVEERC20HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.APPROVEERC20HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// APPROVEERC20HOOKKEY is a free data retrieval call binding the contract method 0x6aa8f025.
//
// Solidity: function APPROVE_ERC20_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) APPROVEERC20HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.APPROVEERC20HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// APPROVEWITHPERMIT2HOOKKEY is a free data retrieval call binding the contract method 0xcd858547.
//
// Solidity: function APPROVE_WITH_PERMIT2_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) APPROVEWITHPERMIT2HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "APPROVE_WITH_PERMIT2_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// APPROVEWITHPERMIT2HOOKKEY is a free data retrieval call binding the contract method 0xcd858547.
//
// Solidity: function APPROVE_WITH_PERMIT2_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) APPROVEWITHPERMIT2HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.APPROVEWITHPERMIT2HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// APPROVEWITHPERMIT2HOOKKEY is a free data retrieval call binding the contract method 0xcd858547.
//
// Solidity: function APPROVE_WITH_PERMIT2_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) APPROVEWITHPERMIT2HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.APPROVEWITHPERMIT2HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// BANKMANAGERKEY is a free data retrieval call binding the contract method 0x517f286f.
//
// Solidity: function BANK_MANAGER_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) BANKMANAGERKEY(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "BANK_MANAGER_KEY")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// BANKMANAGERKEY is a free data retrieval call binding the contract method 0x517f286f.
//
// Solidity: function BANK_MANAGER_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) BANKMANAGERKEY() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.BANKMANAGERKEY(&_AcrossV3AdapterTest.CallOpts)
}

// BANKMANAGERKEY is a free data retrieval call binding the contract method 0x517f286f.
//
// Solidity: function BANK_MANAGER_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) BANKMANAGERKEY() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.BANKMANAGERKEY(&_AcrossV3AdapterTest.CallOpts)
}

// BASE is a free data retrieval call binding the contract method 0xec342ad0.
//
// Solidity: function BASE() view returns(uint64)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) BASE(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "BASE")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// BASE is a free data retrieval call binding the contract method 0xec342ad0.
//
// Solidity: function BASE() view returns(uint64)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) BASE() (uint64, error) {
	return _AcrossV3AdapterTest.Contract.BASE(&_AcrossV3AdapterTest.CallOpts)
}

// BASE is a free data retrieval call binding the contract method 0xec342ad0.
//
// Solidity: function BASE() view returns(uint64)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) BASE() (uint64, error) {
	return _AcrossV3AdapterTest.Contract.BASE(&_AcrossV3AdapterTest.CallOpts)
}

// BASEBLOCK is a free data retrieval call binding the contract method 0x7bb647db.
//
// Solidity: function BASE_BLOCK() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) BASEBLOCK(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "BASE_BLOCK")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// BASEBLOCK is a free data retrieval call binding the contract method 0x7bb647db.
//
// Solidity: function BASE_BLOCK() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) BASEBLOCK() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.BASEBLOCK(&_AcrossV3AdapterTest.CallOpts)
}

// BASEBLOCK is a free data retrieval call binding the contract method 0x7bb647db.
//
// Solidity: function BASE_BLOCK() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) BASEBLOCK() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.BASEBLOCK(&_AcrossV3AdapterTest.CallOpts)
}

// BASEKEY is a free data retrieval call binding the contract method 0x57dfb172.
//
// Solidity: function BASE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) BASEKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "BASE_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// BASEKEY is a free data retrieval call binding the contract method 0x57dfb172.
//
// Solidity: function BASE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) BASEKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.BASEKEY(&_AcrossV3AdapterTest.CallOpts)
}

// BASEKEY is a free data retrieval call binding the contract method 0x57dfb172.
//
// Solidity: function BASE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) BASEKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.BASEKEY(&_AcrossV3AdapterTest.CallOpts)
}

// BASERPCURLKEY is a free data retrieval call binding the contract method 0x1df36168.
//
// Solidity: function BASE_RPC_URL_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) BASERPCURLKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "BASE_RPC_URL_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// BASERPCURLKEY is a free data retrieval call binding the contract method 0x1df36168.
//
// Solidity: function BASE_RPC_URL_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) BASERPCURLKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.BASERPCURLKEY(&_AcrossV3AdapterTest.CallOpts)
}

// BASERPCURLKEY is a free data retrieval call binding the contract method 0x1df36168.
//
// Solidity: function BASE_RPC_URL_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) BASERPCURLKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.BASERPCURLKEY(&_AcrossV3AdapterTest.CallOpts)
}

// BATCHTRANSFERFROMHOOKKEY is a free data retrieval call binding the contract method 0x1a139bb2.
//
// Solidity: function BATCH_TRANSFER_FROM_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) BATCHTRANSFERFROMHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "BATCH_TRANSFER_FROM_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// BATCHTRANSFERFROMHOOKKEY is a free data retrieval call binding the contract method 0x1a139bb2.
//
// Solidity: function BATCH_TRANSFER_FROM_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) BATCHTRANSFERFROMHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.BATCHTRANSFERFROMHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// BATCHTRANSFERFROMHOOKKEY is a free data retrieval call binding the contract method 0x1a139bb2.
//
// Solidity: function BATCH_TRANSFER_FROM_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) BATCHTRANSFERFROMHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.BATCHTRANSFERFROMHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// CANCELDEPOSITREQUEST7540HOOKKEY is a free data retrieval call binding the contract method 0x96d3ae7d.
//
// Solidity: function CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CANCELDEPOSITREQUEST7540HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// CANCELDEPOSITREQUEST7540HOOKKEY is a free data retrieval call binding the contract method 0x96d3ae7d.
//
// Solidity: function CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CANCELDEPOSITREQUEST7540HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.CANCELDEPOSITREQUEST7540HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// CANCELDEPOSITREQUEST7540HOOKKEY is a free data retrieval call binding the contract method 0x96d3ae7d.
//
// Solidity: function CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CANCELDEPOSITREQUEST7540HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.CANCELDEPOSITREQUEST7540HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// CANCELREDEEMREQUEST7540HOOKKEY is a free data retrieval call binding the contract method 0x0a039b68.
//
// Solidity: function CANCEL_REDEEM_REQUEST_7540_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CANCELREDEEMREQUEST7540HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CANCEL_REDEEM_REQUEST_7540_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// CANCELREDEEMREQUEST7540HOOKKEY is a free data retrieval call binding the contract method 0x0a039b68.
//
// Solidity: function CANCEL_REDEEM_REQUEST_7540_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CANCELREDEEMREQUEST7540HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.CANCELREDEEMREQUEST7540HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// CANCELREDEEMREQUEST7540HOOKKEY is a free data retrieval call binding the contract method 0x0a039b68.
//
// Solidity: function CANCEL_REDEEM_REQUEST_7540_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CANCELREDEEMREQUEST7540HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.CANCELREDEEMREQUEST7540HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// CENTRIFUGEUSDCVAULTKEY is a free data retrieval call binding the contract method 0x78ef1bbd.
//
// Solidity: function CENTRIFUGE_USDC_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CENTRIFUGEUSDCVAULTKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CENTRIFUGE_USDC_VAULT_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// CENTRIFUGEUSDCVAULTKEY is a free data retrieval call binding the contract method 0x78ef1bbd.
//
// Solidity: function CENTRIFUGE_USDC_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CENTRIFUGEUSDCVAULTKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.CENTRIFUGEUSDCVAULTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// CENTRIFUGEUSDCVAULTKEY is a free data retrieval call binding the contract method 0x78ef1bbd.
//
// Solidity: function CENTRIFUGE_USDC_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CENTRIFUGEUSDCVAULTKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.CENTRIFUGEUSDCVAULTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN10ALOEUSDC is a free data retrieval call binding the contract method 0x240a7120.
//
// Solidity: function CHAIN_10_ALOE_USDC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN10ALOEUSDC(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_10_ALOE_USDC")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN10ALOEUSDC is a free data retrieval call binding the contract method 0x240a7120.
//
// Solidity: function CHAIN_10_ALOE_USDC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN10ALOEUSDC() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN10ALOEUSDC(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN10ALOEUSDC is a free data retrieval call binding the contract method 0x240a7120.
//
// Solidity: function CHAIN_10_ALOE_USDC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN10ALOEUSDC() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN10ALOEUSDC(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN10DAI is a free data retrieval call binding the contract method 0xa96c0ad7.
//
// Solidity: function CHAIN_10_DAI() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN10DAI(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_10_DAI")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN10DAI is a free data retrieval call binding the contract method 0xa96c0ad7.
//
// Solidity: function CHAIN_10_DAI() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN10DAI() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN10DAI(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN10DAI is a free data retrieval call binding the contract method 0xa96c0ad7.
//
// Solidity: function CHAIN_10_DAI() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN10DAI() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN10DAI(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN10NEXUSBOOTSTRAP is a free data retrieval call binding the contract method 0xed0e6baa.
//
// Solidity: function CHAIN_10_NEXUS_BOOTSTRAP() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN10NEXUSBOOTSTRAP(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_10_NEXUS_BOOTSTRAP")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN10NEXUSBOOTSTRAP is a free data retrieval call binding the contract method 0xed0e6baa.
//
// Solidity: function CHAIN_10_NEXUS_BOOTSTRAP() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN10NEXUSBOOTSTRAP() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN10NEXUSBOOTSTRAP(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN10NEXUSBOOTSTRAP is a free data retrieval call binding the contract method 0xed0e6baa.
//
// Solidity: function CHAIN_10_NEXUS_BOOTSTRAP() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN10NEXUSBOOTSTRAP() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN10NEXUSBOOTSTRAP(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN10NEXUSFACTORY is a free data retrieval call binding the contract method 0x276bd652.
//
// Solidity: function CHAIN_10_NEXUS_FACTORY() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN10NEXUSFACTORY(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_10_NEXUS_FACTORY")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN10NEXUSFACTORY is a free data retrieval call binding the contract method 0x276bd652.
//
// Solidity: function CHAIN_10_NEXUS_FACTORY() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN10NEXUSFACTORY() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN10NEXUSFACTORY(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN10NEXUSFACTORY is a free data retrieval call binding the contract method 0x276bd652.
//
// Solidity: function CHAIN_10_NEXUS_FACTORY() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN10NEXUSFACTORY() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN10NEXUSFACTORY(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN10ODOSROUTER is a free data retrieval call binding the contract method 0xfc63c520.
//
// Solidity: function CHAIN_10_ODOS_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN10ODOSROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_10_ODOS_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN10ODOSROUTER is a free data retrieval call binding the contract method 0xfc63c520.
//
// Solidity: function CHAIN_10_ODOS_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN10ODOSROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN10ODOSROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN10ODOSROUTER is a free data retrieval call binding the contract method 0xfc63c520.
//
// Solidity: function CHAIN_10_ODOS_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN10ODOSROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN10ODOSROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN10PENDLEROUTER is a free data retrieval call binding the contract method 0xe46056b9.
//
// Solidity: function CHAIN_10_PENDLE_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN10PENDLEROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_10_PENDLE_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN10PENDLEROUTER is a free data retrieval call binding the contract method 0xe46056b9.
//
// Solidity: function CHAIN_10_PENDLE_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN10PENDLEROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN10PENDLEROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN10PENDLEROUTER is a free data retrieval call binding the contract method 0xe46056b9.
//
// Solidity: function CHAIN_10_PENDLE_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN10PENDLEROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN10PENDLEROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN10PENDLESWAP is a free data retrieval call binding the contract method 0x88aebdae.
//
// Solidity: function CHAIN_10_PENDLE_SWAP() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN10PENDLESWAP(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_10_PENDLE_SWAP")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN10PENDLESWAP is a free data retrieval call binding the contract method 0x88aebdae.
//
// Solidity: function CHAIN_10_PENDLE_SWAP() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN10PENDLESWAP() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN10PENDLESWAP(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN10PENDLESWAP is a free data retrieval call binding the contract method 0x88aebdae.
//
// Solidity: function CHAIN_10_PENDLE_SWAP() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN10PENDLESWAP() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN10PENDLESWAP(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN10SPECTRAROUTER is a free data retrieval call binding the contract method 0x89822ee9.
//
// Solidity: function CHAIN_10_SPECTRA_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN10SPECTRAROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_10_SPECTRA_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN10SPECTRAROUTER is a free data retrieval call binding the contract method 0x89822ee9.
//
// Solidity: function CHAIN_10_SPECTRA_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN10SPECTRAROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN10SPECTRAROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN10SPECTRAROUTER is a free data retrieval call binding the contract method 0x89822ee9.
//
// Solidity: function CHAIN_10_SPECTRA_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN10SPECTRAROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN10SPECTRAROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN10SPOKEPOOLV3ADDRESS is a free data retrieval call binding the contract method 0x4ddf3ce9.
//
// Solidity: function CHAIN_10_SPOKE_POOL_V3_ADDRESS() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN10SPOKEPOOLV3ADDRESS(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_10_SPOKE_POOL_V3_ADDRESS")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN10SPOKEPOOLV3ADDRESS is a free data retrieval call binding the contract method 0x4ddf3ce9.
//
// Solidity: function CHAIN_10_SPOKE_POOL_V3_ADDRESS() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN10SPOKEPOOLV3ADDRESS() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN10SPOKEPOOLV3ADDRESS(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN10SPOKEPOOLV3ADDRESS is a free data retrieval call binding the contract method 0x4ddf3ce9.
//
// Solidity: function CHAIN_10_SPOKE_POOL_V3_ADDRESS() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN10SPOKEPOOLV3ADDRESS() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN10SPOKEPOOLV3ADDRESS(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN10USDC is a free data retrieval call binding the contract method 0xcc7612f2.
//
// Solidity: function CHAIN_10_USDC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN10USDC(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_10_USDC")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN10USDC is a free data retrieval call binding the contract method 0xcc7612f2.
//
// Solidity: function CHAIN_10_USDC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN10USDC() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN10USDC(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN10USDC is a free data retrieval call binding the contract method 0xcc7612f2.
//
// Solidity: function CHAIN_10_USDC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN10USDC() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN10USDC(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN10USDCE is a free data retrieval call binding the contract method 0xeec6d812.
//
// Solidity: function CHAIN_10_USDCE() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN10USDCE(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_10_USDCE")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN10USDCE is a free data retrieval call binding the contract method 0xeec6d812.
//
// Solidity: function CHAIN_10_USDCE() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN10USDCE() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN10USDCE(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN10USDCE is a free data retrieval call binding the contract method 0xeec6d812.
//
// Solidity: function CHAIN_10_USDCE() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN10USDCE() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN10USDCE(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN10WETH is a free data retrieval call binding the contract method 0x5da57f00.
//
// Solidity: function CHAIN_10_WETH() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN10WETH(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_10_WETH")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN10WETH is a free data retrieval call binding the contract method 0x5da57f00.
//
// Solidity: function CHAIN_10_WETH() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN10WETH() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN10WETH(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN10WETH is a free data retrieval call binding the contract method 0x5da57f00.
//
// Solidity: function CHAIN_10_WETH() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN10WETH() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN10WETH(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1AAVEVAULT is a free data retrieval call binding the contract method 0x1ba7c470.
//
// Solidity: function CHAIN_1_AAVE_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1AAVEVAULT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_AAVE_VAULT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1AAVEVAULT is a free data retrieval call binding the contract method 0x1ba7c470.
//
// Solidity: function CHAIN_1_AAVE_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1AAVEVAULT() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1AAVEVAULT(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1AAVEVAULT is a free data retrieval call binding the contract method 0x1ba7c470.
//
// Solidity: function CHAIN_1_AAVE_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1AAVEVAULT() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1AAVEVAULT(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1CENTRIFUGEUSDC is a free data retrieval call binding the contract method 0xf79a6f90.
//
// Solidity: function CHAIN_1_CENTRIFUGE_USDC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1CENTRIFUGEUSDC(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_CENTRIFUGE_USDC")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1CENTRIFUGEUSDC is a free data retrieval call binding the contract method 0xf79a6f90.
//
// Solidity: function CHAIN_1_CENTRIFUGE_USDC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1CENTRIFUGEUSDC() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1CENTRIFUGEUSDC(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1CENTRIFUGEUSDC is a free data retrieval call binding the contract method 0xf79a6f90.
//
// Solidity: function CHAIN_1_CENTRIFUGE_USDC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1CENTRIFUGEUSDC() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1CENTRIFUGEUSDC(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1CUSDO is a free data retrieval call binding the contract method 0xc0a7c442.
//
// Solidity: function CHAIN_1_CUSDO() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1CUSDO(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_CUSDO")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1CUSDO is a free data retrieval call binding the contract method 0xc0a7c442.
//
// Solidity: function CHAIN_1_CUSDO() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1CUSDO() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1CUSDO(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1CUSDO is a free data retrieval call binding the contract method 0xc0a7c442.
//
// Solidity: function CHAIN_1_CUSDO() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1CUSDO() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1CUSDO(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1DAI is a free data retrieval call binding the contract method 0x0f704fee.
//
// Solidity: function CHAIN_1_DAI() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1DAI(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_DAI")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1DAI is a free data retrieval call binding the contract method 0x0f704fee.
//
// Solidity: function CHAIN_1_DAI() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1DAI() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1DAI(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1DAI is a free data retrieval call binding the contract method 0x0f704fee.
//
// Solidity: function CHAIN_1_DAI() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1DAI() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1DAI(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1EULERVAULT is a free data retrieval call binding the contract method 0x31fca8a2.
//
// Solidity: function CHAIN_1_EULER_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1EULERVAULT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_EULER_VAULT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1EULERVAULT is a free data retrieval call binding the contract method 0x31fca8a2.
//
// Solidity: function CHAIN_1_EULER_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1EULERVAULT() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1EULERVAULT(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1EULERVAULT is a free data retrieval call binding the contract method 0x31fca8a2.
//
// Solidity: function CHAIN_1_EULER_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1EULERVAULT() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1EULERVAULT(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1FLUIDVAULT is a free data retrieval call binding the contract method 0xe582fe3b.
//
// Solidity: function CHAIN_1_FLUID_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1FLUIDVAULT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_FLUID_VAULT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1FLUIDVAULT is a free data retrieval call binding the contract method 0xe582fe3b.
//
// Solidity: function CHAIN_1_FLUID_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1FLUIDVAULT() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1FLUIDVAULT(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1FLUIDVAULT is a free data retrieval call binding the contract method 0xe582fe3b.
//
// Solidity: function CHAIN_1_FLUID_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1FLUIDVAULT() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1FLUIDVAULT(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1GEAR is a free data retrieval call binding the contract method 0xc9319814.
//
// Solidity: function CHAIN_1_GEAR() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1GEAR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_GEAR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1GEAR is a free data retrieval call binding the contract method 0xc9319814.
//
// Solidity: function CHAIN_1_GEAR() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1GEAR() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1GEAR(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1GEAR is a free data retrieval call binding the contract method 0xc9319814.
//
// Solidity: function CHAIN_1_GEAR() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1GEAR() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1GEAR(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1GEARBOXSTAKING is a free data retrieval call binding the contract method 0xb6a20f3f.
//
// Solidity: function CHAIN_1_GEARBOX_STAKING() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1GEARBOXSTAKING(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_GEARBOX_STAKING")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1GEARBOXSTAKING is a free data retrieval call binding the contract method 0xb6a20f3f.
//
// Solidity: function CHAIN_1_GEARBOX_STAKING() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1GEARBOXSTAKING() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1GEARBOXSTAKING(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1GEARBOXSTAKING is a free data retrieval call binding the contract method 0xb6a20f3f.
//
// Solidity: function CHAIN_1_GEARBOX_STAKING() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1GEARBOXSTAKING() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1GEARBOXSTAKING(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1GEARBOXVAULT is a free data retrieval call binding the contract method 0x6077c7b7.
//
// Solidity: function CHAIN_1_GEARBOX_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1GEARBOXVAULT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_GEARBOX_VAULT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1GEARBOXVAULT is a free data retrieval call binding the contract method 0x6077c7b7.
//
// Solidity: function CHAIN_1_GEARBOX_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1GEARBOXVAULT() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1GEARBOXVAULT(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1GEARBOXVAULT is a free data retrieval call binding the contract method 0x6077c7b7.
//
// Solidity: function CHAIN_1_GEARBOX_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1GEARBOXVAULT() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1GEARBOXVAULT(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1MORPHOVAULT is a free data retrieval call binding the contract method 0x8bb5a798.
//
// Solidity: function CHAIN_1_MORPHO_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1MORPHOVAULT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_MORPHO_VAULT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1MORPHOVAULT is a free data retrieval call binding the contract method 0x8bb5a798.
//
// Solidity: function CHAIN_1_MORPHO_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1MORPHOVAULT() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1MORPHOVAULT(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1MORPHOVAULT is a free data retrieval call binding the contract method 0x8bb5a798.
//
// Solidity: function CHAIN_1_MORPHO_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1MORPHOVAULT() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1MORPHOVAULT(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1NEXUSBOOTSTRAP is a free data retrieval call binding the contract method 0x03a48ba8.
//
// Solidity: function CHAIN_1_NEXUS_BOOTSTRAP() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1NEXUSBOOTSTRAP(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_NEXUS_BOOTSTRAP")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1NEXUSBOOTSTRAP is a free data retrieval call binding the contract method 0x03a48ba8.
//
// Solidity: function CHAIN_1_NEXUS_BOOTSTRAP() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1NEXUSBOOTSTRAP() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1NEXUSBOOTSTRAP(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1NEXUSBOOTSTRAP is a free data retrieval call binding the contract method 0x03a48ba8.
//
// Solidity: function CHAIN_1_NEXUS_BOOTSTRAP() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1NEXUSBOOTSTRAP() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1NEXUSBOOTSTRAP(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1NEXUSFACTORY is a free data retrieval call binding the contract method 0xfeff3a58.
//
// Solidity: function CHAIN_1_NEXUS_FACTORY() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1NEXUSFACTORY(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_NEXUS_FACTORY")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1NEXUSFACTORY is a free data retrieval call binding the contract method 0xfeff3a58.
//
// Solidity: function CHAIN_1_NEXUS_FACTORY() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1NEXUSFACTORY() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1NEXUSFACTORY(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1NEXUSFACTORY is a free data retrieval call binding the contract method 0xfeff3a58.
//
// Solidity: function CHAIN_1_NEXUS_FACTORY() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1NEXUSFACTORY() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1NEXUSFACTORY(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1ODOSROUTER is a free data retrieval call binding the contract method 0xc2933cd1.
//
// Solidity: function CHAIN_1_ODOS_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1ODOSROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_ODOS_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1ODOSROUTER is a free data retrieval call binding the contract method 0xc2933cd1.
//
// Solidity: function CHAIN_1_ODOS_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1ODOSROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1ODOSROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1ODOSROUTER is a free data retrieval call binding the contract method 0xc2933cd1.
//
// Solidity: function CHAIN_1_ODOS_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1ODOSROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1ODOSROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1PENDLEETHENA is a free data retrieval call binding the contract method 0x911d4b7b.
//
// Solidity: function CHAIN_1_PENDLE_ETHENA() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1PENDLEETHENA(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_PENDLE_ETHENA")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1PENDLEETHENA is a free data retrieval call binding the contract method 0x911d4b7b.
//
// Solidity: function CHAIN_1_PENDLE_ETHENA() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1PENDLEETHENA() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1PENDLEETHENA(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1PENDLEETHENA is a free data retrieval call binding the contract method 0x911d4b7b.
//
// Solidity: function CHAIN_1_PENDLE_ETHENA() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1PENDLEETHENA() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1PENDLEETHENA(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1PENDLEROUTER is a free data retrieval call binding the contract method 0xb6a22dd6.
//
// Solidity: function CHAIN_1_PENDLE_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1PENDLEROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_PENDLE_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1PENDLEROUTER is a free data retrieval call binding the contract method 0xb6a22dd6.
//
// Solidity: function CHAIN_1_PENDLE_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1PENDLEROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1PENDLEROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1PENDLEROUTER is a free data retrieval call binding the contract method 0xb6a22dd6.
//
// Solidity: function CHAIN_1_PENDLE_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1PENDLEROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1PENDLEROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1PENDLESWAP is a free data retrieval call binding the contract method 0x52ea38f5.
//
// Solidity: function CHAIN_1_PENDLE_SWAP() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1PENDLESWAP(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_PENDLE_SWAP")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1PENDLESWAP is a free data retrieval call binding the contract method 0x52ea38f5.
//
// Solidity: function CHAIN_1_PENDLE_SWAP() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1PENDLESWAP() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1PENDLESWAP(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1PENDLESWAP is a free data retrieval call binding the contract method 0x52ea38f5.
//
// Solidity: function CHAIN_1_PENDLE_SWAP() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1PENDLESWAP() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1PENDLESWAP(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1SPECTRAPTTTOKEN is a free data retrieval call binding the contract method 0xdc2f079e.
//
// Solidity: function CHAIN_1_SPECTRA_PTT_TOKEN() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1SPECTRAPTTTOKEN(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_SPECTRA_PTT_TOKEN")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1SPECTRAPTTTOKEN is a free data retrieval call binding the contract method 0xdc2f079e.
//
// Solidity: function CHAIN_1_SPECTRA_PTT_TOKEN() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1SPECTRAPTTTOKEN() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1SPECTRAPTTTOKEN(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1SPECTRAPTTTOKEN is a free data retrieval call binding the contract method 0xdc2f079e.
//
// Solidity: function CHAIN_1_SPECTRA_PTT_TOKEN() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1SPECTRAPTTTOKEN() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1SPECTRAPTTTOKEN(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1SPECTRAPTIPORUSDC is a free data retrieval call binding the contract method 0xb5cc660e.
//
// Solidity: function CHAIN_1_SPECTRA_PT_IPOR_USDC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1SPECTRAPTIPORUSDC(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_SPECTRA_PT_IPOR_USDC")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1SPECTRAPTIPORUSDC is a free data retrieval call binding the contract method 0xb5cc660e.
//
// Solidity: function CHAIN_1_SPECTRA_PT_IPOR_USDC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1SPECTRAPTIPORUSDC() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1SPECTRAPTIPORUSDC(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1SPECTRAPTIPORUSDC is a free data retrieval call binding the contract method 0xb5cc660e.
//
// Solidity: function CHAIN_1_SPECTRA_PT_IPOR_USDC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1SPECTRAPTIPORUSDC() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1SPECTRAPTIPORUSDC(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1SPECTRAROUTER is a free data retrieval call binding the contract method 0xb17efd5f.
//
// Solidity: function CHAIN_1_SPECTRA_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1SPECTRAROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_SPECTRA_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1SPECTRAROUTER is a free data retrieval call binding the contract method 0xb17efd5f.
//
// Solidity: function CHAIN_1_SPECTRA_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1SPECTRAROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1SPECTRAROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1SPECTRAROUTER is a free data retrieval call binding the contract method 0xb17efd5f.
//
// Solidity: function CHAIN_1_SPECTRA_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1SPECTRAROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1SPECTRAROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1SPOKEPOOLV3ADDRESS is a free data retrieval call binding the contract method 0xcce4da2a.
//
// Solidity: function CHAIN_1_SPOKE_POOL_V3_ADDRESS() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1SPOKEPOOLV3ADDRESS(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_SPOKE_POOL_V3_ADDRESS")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1SPOKEPOOLV3ADDRESS is a free data retrieval call binding the contract method 0xcce4da2a.
//
// Solidity: function CHAIN_1_SPOKE_POOL_V3_ADDRESS() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1SPOKEPOOLV3ADDRESS() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1SPOKEPOOLV3ADDRESS(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1SPOKEPOOLV3ADDRESS is a free data retrieval call binding the contract method 0xcce4da2a.
//
// Solidity: function CHAIN_1_SPOKE_POOL_V3_ADDRESS() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1SPOKEPOOLV3ADDRESS() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1SPOKEPOOLV3ADDRESS(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1SUSDE is a free data retrieval call binding the contract method 0x46674bfc.
//
// Solidity: function CHAIN_1_SUSDE() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1SUSDE(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_SUSDE")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1SUSDE is a free data retrieval call binding the contract method 0x46674bfc.
//
// Solidity: function CHAIN_1_SUSDE() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1SUSDE() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1SUSDE(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1SUSDE is a free data retrieval call binding the contract method 0x46674bfc.
//
// Solidity: function CHAIN_1_SUSDE() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1SUSDE() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1SUSDE(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1USDC is a free data retrieval call binding the contract method 0xed9fe105.
//
// Solidity: function CHAIN_1_USDC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1USDC(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_USDC")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1USDC is a free data retrieval call binding the contract method 0xed9fe105.
//
// Solidity: function CHAIN_1_USDC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1USDC() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1USDC(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1USDC is a free data retrieval call binding the contract method 0xed9fe105.
//
// Solidity: function CHAIN_1_USDC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1USDC() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1USDC(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1USDE is a free data retrieval call binding the contract method 0x309e2478.
//
// Solidity: function CHAIN_1_USDE() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1USDE(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_USDE")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1USDE is a free data retrieval call binding the contract method 0x309e2478.
//
// Solidity: function CHAIN_1_USDE() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1USDE() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1USDE(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1USDE is a free data retrieval call binding the contract method 0x309e2478.
//
// Solidity: function CHAIN_1_USDE() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1USDE() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1USDE(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1USDO is a free data retrieval call binding the contract method 0x9ba4699d.
//
// Solidity: function CHAIN_1_USDO() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1USDO(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_USDO")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1USDO is a free data retrieval call binding the contract method 0x9ba4699d.
//
// Solidity: function CHAIN_1_USDO() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1USDO() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1USDO(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1USDO is a free data retrieval call binding the contract method 0x9ba4699d.
//
// Solidity: function CHAIN_1_USDO() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1USDO() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1USDO(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1WBTC is a free data retrieval call binding the contract method 0x5c920b64.
//
// Solidity: function CHAIN_1_WBTC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1WBTC(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_WBTC")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1WBTC is a free data retrieval call binding the contract method 0x5c920b64.
//
// Solidity: function CHAIN_1_WBTC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1WBTC() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1WBTC(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1WBTC is a free data retrieval call binding the contract method 0x5c920b64.
//
// Solidity: function CHAIN_1_WBTC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1WBTC() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1WBTC(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1WETH is a free data retrieval call binding the contract method 0x57009145.
//
// Solidity: function CHAIN_1_WETH() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1WETH(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_WETH")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1WETH is a free data retrieval call binding the contract method 0x57009145.
//
// Solidity: function CHAIN_1_WETH() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1WETH() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1WETH(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1WETH is a free data retrieval call binding the contract method 0x57009145.
//
// Solidity: function CHAIN_1_WETH() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1WETH() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1WETH(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1WSTETH is a free data retrieval call binding the contract method 0xff412875.
//
// Solidity: function CHAIN_1_WST_ETH() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1WSTETH(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_WST_ETH")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1WSTETH is a free data retrieval call binding the contract method 0xff412875.
//
// Solidity: function CHAIN_1_WST_ETH() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1WSTETH() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1WSTETH(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1WSTETH is a free data retrieval call binding the contract method 0xff412875.
//
// Solidity: function CHAIN_1_WST_ETH() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1WSTETH() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1WSTETH(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1YEARNVAULT is a free data retrieval call binding the contract method 0x2c9bf333.
//
// Solidity: function CHAIN_1_YEARN_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN1YEARNVAULT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_1_YEARN_VAULT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN1YEARNVAULT is a free data retrieval call binding the contract method 0x2c9bf333.
//
// Solidity: function CHAIN_1_YEARN_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN1YEARNVAULT() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1YEARNVAULT(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN1YEARNVAULT is a free data retrieval call binding the contract method 0x2c9bf333.
//
// Solidity: function CHAIN_1_YEARN_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN1YEARNVAULT() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN1YEARNVAULT(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453AAVEBASEWETH is a free data retrieval call binding the contract method 0xbd02d736.
//
// Solidity: function CHAIN_8453_AAVE_BASE_WETH() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN8453AAVEBASEWETH(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_8453_AAVE_BASE_WETH")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453AAVEBASEWETH is a free data retrieval call binding the contract method 0xbd02d736.
//
// Solidity: function CHAIN_8453_AAVE_BASE_WETH() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN8453AAVEBASEWETH() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453AAVEBASEWETH(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453AAVEBASEWETH is a free data retrieval call binding the contract method 0xbd02d736.
//
// Solidity: function CHAIN_8453_AAVE_BASE_WETH() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN8453AAVEBASEWETH() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453AAVEBASEWETH(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453DAI is a free data retrieval call binding the contract method 0x907073c2.
//
// Solidity: function CHAIN_8453_DAI() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN8453DAI(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_8453_DAI")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453DAI is a free data retrieval call binding the contract method 0x907073c2.
//
// Solidity: function CHAIN_8453_DAI() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN8453DAI() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453DAI(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453DAI is a free data retrieval call binding the contract method 0x907073c2.
//
// Solidity: function CHAIN_8453_DAI() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN8453DAI() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453DAI(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453MORPHOGAUNTLETUSDCPRIME is a free data retrieval call binding the contract method 0xfa88e2ee.
//
// Solidity: function CHAIN_8453_MORPHO_GAUNTLET_USDC_PRIME() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN8453MORPHOGAUNTLETUSDCPRIME(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_8453_MORPHO_GAUNTLET_USDC_PRIME")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453MORPHOGAUNTLETUSDCPRIME is a free data retrieval call binding the contract method 0xfa88e2ee.
//
// Solidity: function CHAIN_8453_MORPHO_GAUNTLET_USDC_PRIME() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN8453MORPHOGAUNTLETUSDCPRIME() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453MORPHOGAUNTLETUSDCPRIME(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453MORPHOGAUNTLETUSDCPRIME is a free data retrieval call binding the contract method 0xfa88e2ee.
//
// Solidity: function CHAIN_8453_MORPHO_GAUNTLET_USDC_PRIME() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN8453MORPHOGAUNTLETUSDCPRIME() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453MORPHOGAUNTLETUSDCPRIME(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453MORPHOGAUNTLETWETHCORE is a free data retrieval call binding the contract method 0xb67474d2.
//
// Solidity: function CHAIN_8453_MORPHO_GAUNTLET_WETH_CORE() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN8453MORPHOGAUNTLETWETHCORE(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_8453_MORPHO_GAUNTLET_WETH_CORE")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453MORPHOGAUNTLETWETHCORE is a free data retrieval call binding the contract method 0xb67474d2.
//
// Solidity: function CHAIN_8453_MORPHO_GAUNTLET_WETH_CORE() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN8453MORPHOGAUNTLETWETHCORE() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453MORPHOGAUNTLETWETHCORE(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453MORPHOGAUNTLETWETHCORE is a free data retrieval call binding the contract method 0xb67474d2.
//
// Solidity: function CHAIN_8453_MORPHO_GAUNTLET_WETH_CORE() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN8453MORPHOGAUNTLETWETHCORE() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453MORPHOGAUNTLETWETHCORE(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453NEXUSBOOTSTRAP is a free data retrieval call binding the contract method 0x436b1e6e.
//
// Solidity: function CHAIN_8453_NEXUS_BOOTSTRAP() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN8453NEXUSBOOTSTRAP(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_8453_NEXUS_BOOTSTRAP")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453NEXUSBOOTSTRAP is a free data retrieval call binding the contract method 0x436b1e6e.
//
// Solidity: function CHAIN_8453_NEXUS_BOOTSTRAP() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN8453NEXUSBOOTSTRAP() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453NEXUSBOOTSTRAP(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453NEXUSBOOTSTRAP is a free data retrieval call binding the contract method 0x436b1e6e.
//
// Solidity: function CHAIN_8453_NEXUS_BOOTSTRAP() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN8453NEXUSBOOTSTRAP() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453NEXUSBOOTSTRAP(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453NEXUSFACTORY is a free data retrieval call binding the contract method 0x3e9b726b.
//
// Solidity: function CHAIN_8453_NEXUS_FACTORY() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN8453NEXUSFACTORY(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_8453_NEXUS_FACTORY")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453NEXUSFACTORY is a free data retrieval call binding the contract method 0x3e9b726b.
//
// Solidity: function CHAIN_8453_NEXUS_FACTORY() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN8453NEXUSFACTORY() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453NEXUSFACTORY(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453NEXUSFACTORY is a free data retrieval call binding the contract method 0x3e9b726b.
//
// Solidity: function CHAIN_8453_NEXUS_FACTORY() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN8453NEXUSFACTORY() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453NEXUSFACTORY(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453ODOSROUTER is a free data retrieval call binding the contract method 0xeb6d020d.
//
// Solidity: function CHAIN_8453_ODOS_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN8453ODOSROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_8453_ODOS_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453ODOSROUTER is a free data retrieval call binding the contract method 0xeb6d020d.
//
// Solidity: function CHAIN_8453_ODOS_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN8453ODOSROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453ODOSROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453ODOSROUTER is a free data retrieval call binding the contract method 0xeb6d020d.
//
// Solidity: function CHAIN_8453_ODOS_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN8453ODOSROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453ODOSROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453PENDLEROUTER is a free data retrieval call binding the contract method 0xd63555ac.
//
// Solidity: function CHAIN_8453_PENDLE_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN8453PENDLEROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_8453_PENDLE_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453PENDLEROUTER is a free data retrieval call binding the contract method 0xd63555ac.
//
// Solidity: function CHAIN_8453_PENDLE_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN8453PENDLEROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453PENDLEROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453PENDLEROUTER is a free data retrieval call binding the contract method 0xd63555ac.
//
// Solidity: function CHAIN_8453_PENDLE_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN8453PENDLEROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453PENDLEROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453PENDLESWAP is a free data retrieval call binding the contract method 0x7f95398a.
//
// Solidity: function CHAIN_8453_PENDLE_SWAP() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN8453PENDLESWAP(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_8453_PENDLE_SWAP")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453PENDLESWAP is a free data retrieval call binding the contract method 0x7f95398a.
//
// Solidity: function CHAIN_8453_PENDLE_SWAP() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN8453PENDLESWAP() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453PENDLESWAP(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453PENDLESWAP is a free data retrieval call binding the contract method 0x7f95398a.
//
// Solidity: function CHAIN_8453_PENDLE_SWAP() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN8453PENDLESWAP() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453PENDLESWAP(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453SPARKPSM3 is a free data retrieval call binding the contract method 0x9a36e478.
//
// Solidity: function CHAIN_8453_SPARK_PSM3() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN8453SPARKPSM3(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_8453_SPARK_PSM3")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453SPARKPSM3 is a free data retrieval call binding the contract method 0x9a36e478.
//
// Solidity: function CHAIN_8453_SPARK_PSM3() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN8453SPARKPSM3() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453SPARKPSM3(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453SPARKPSM3 is a free data retrieval call binding the contract method 0x9a36e478.
//
// Solidity: function CHAIN_8453_SPARK_PSM3() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN8453SPARKPSM3() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453SPARKPSM3(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453SPARKUSDCVAULT is a free data retrieval call binding the contract method 0xca54d672.
//
// Solidity: function CHAIN_8453_SPARK_USDC_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN8453SPARKUSDCVAULT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_8453_SPARK_USDC_VAULT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453SPARKUSDCVAULT is a free data retrieval call binding the contract method 0xca54d672.
//
// Solidity: function CHAIN_8453_SPARK_USDC_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN8453SPARKUSDCVAULT() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453SPARKUSDCVAULT(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453SPARKUSDCVAULT is a free data retrieval call binding the contract method 0xca54d672.
//
// Solidity: function CHAIN_8453_SPARK_USDC_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN8453SPARKUSDCVAULT() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453SPARKUSDCVAULT(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453SPECTRAROUTER is a free data retrieval call binding the contract method 0x421bcedd.
//
// Solidity: function CHAIN_8453_SPECTRA_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN8453SPECTRAROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_8453_SPECTRA_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453SPECTRAROUTER is a free data retrieval call binding the contract method 0x421bcedd.
//
// Solidity: function CHAIN_8453_SPECTRA_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN8453SPECTRAROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453SPECTRAROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453SPECTRAROUTER is a free data retrieval call binding the contract method 0x421bcedd.
//
// Solidity: function CHAIN_8453_SPECTRA_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN8453SPECTRAROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453SPECTRAROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453SPOKEPOOLV3ADDRESS is a free data retrieval call binding the contract method 0x1da5f587.
//
// Solidity: function CHAIN_8453_SPOKE_POOL_V3_ADDRESS() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN8453SPOKEPOOLV3ADDRESS(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_8453_SPOKE_POOL_V3_ADDRESS")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453SPOKEPOOLV3ADDRESS is a free data retrieval call binding the contract method 0x1da5f587.
//
// Solidity: function CHAIN_8453_SPOKE_POOL_V3_ADDRESS() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN8453SPOKEPOOLV3ADDRESS() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453SPOKEPOOLV3ADDRESS(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453SPOKEPOOLV3ADDRESS is a free data retrieval call binding the contract method 0x1da5f587.
//
// Solidity: function CHAIN_8453_SPOKE_POOL_V3_ADDRESS() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN8453SPOKEPOOLV3ADDRESS() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453SPOKEPOOLV3ADDRESS(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453SUPERUSDCVAULT is a free data retrieval call binding the contract method 0xcf75f681.
//
// Solidity: function CHAIN_8453_SUPER_USDC_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN8453SUPERUSDCVAULT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_8453_SUPER_USDC_VAULT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453SUPERUSDCVAULT is a free data retrieval call binding the contract method 0xcf75f681.
//
// Solidity: function CHAIN_8453_SUPER_USDC_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN8453SUPERUSDCVAULT() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453SUPERUSDCVAULT(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453SUPERUSDCVAULT is a free data retrieval call binding the contract method 0xcf75f681.
//
// Solidity: function CHAIN_8453_SUPER_USDC_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN8453SUPERUSDCVAULT() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453SUPERUSDCVAULT(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453SUSDS is a free data retrieval call binding the contract method 0x16a10836.
//
// Solidity: function CHAIN_8453_SUSDS() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN8453SUSDS(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_8453_SUSDS")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453SUSDS is a free data retrieval call binding the contract method 0x16a10836.
//
// Solidity: function CHAIN_8453_SUSDS() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN8453SUSDS() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453SUSDS(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453SUSDS is a free data retrieval call binding the contract method 0x16a10836.
//
// Solidity: function CHAIN_8453_SUSDS() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN8453SUSDS() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453SUSDS(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453USDC is a free data retrieval call binding the contract method 0xffdd469c.
//
// Solidity: function CHAIN_8453_USDC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN8453USDC(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_8453_USDC")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453USDC is a free data retrieval call binding the contract method 0xffdd469c.
//
// Solidity: function CHAIN_8453_USDC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN8453USDC() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453USDC(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453USDC is a free data retrieval call binding the contract method 0xffdd469c.
//
// Solidity: function CHAIN_8453_USDC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN8453USDC() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453USDC(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453USDS is a free data retrieval call binding the contract method 0x07ba6519.
//
// Solidity: function CHAIN_8453_USDS() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN8453USDS(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_8453_USDS")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453USDS is a free data retrieval call binding the contract method 0x07ba6519.
//
// Solidity: function CHAIN_8453_USDS() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN8453USDS() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453USDS(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453USDS is a free data retrieval call binding the contract method 0x07ba6519.
//
// Solidity: function CHAIN_8453_USDS() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN8453USDS() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453USDS(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453WETH is a free data retrieval call binding the contract method 0x70ac2501.
//
// Solidity: function CHAIN_8453_WETH() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN8453WETH(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_8453_WETH")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453WETH is a free data retrieval call binding the contract method 0x70ac2501.
//
// Solidity: function CHAIN_8453_WETH() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN8453WETH() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453WETH(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453WETH is a free data retrieval call binding the contract method 0x70ac2501.
//
// Solidity: function CHAIN_8453_WETH() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN8453WETH() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453WETH(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453YOBTCVAULT is a free data retrieval call binding the contract method 0xa9810059.
//
// Solidity: function CHAIN_8453_YO_BTC_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN8453YOBTCVAULT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_8453_YO_BTC_VAULT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453YOBTCVAULT is a free data retrieval call binding the contract method 0xa9810059.
//
// Solidity: function CHAIN_8453_YO_BTC_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN8453YOBTCVAULT() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453YOBTCVAULT(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453YOBTCVAULT is a free data retrieval call binding the contract method 0xa9810059.
//
// Solidity: function CHAIN_8453_YO_BTC_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN8453YOBTCVAULT() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453YOBTCVAULT(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453YOETHVAULT is a free data retrieval call binding the contract method 0xddcb4c37.
//
// Solidity: function CHAIN_8453_YO_ETH_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN8453YOETHVAULT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_8453_YO_ETH_VAULT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453YOETHVAULT is a free data retrieval call binding the contract method 0xddcb4c37.
//
// Solidity: function CHAIN_8453_YO_ETH_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN8453YOETHVAULT() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453YOETHVAULT(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453YOETHVAULT is a free data retrieval call binding the contract method 0xddcb4c37.
//
// Solidity: function CHAIN_8453_YO_ETH_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN8453YOETHVAULT() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453YOETHVAULT(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453YOUSDVAULT is a free data retrieval call binding the contract method 0x8753565f.
//
// Solidity: function CHAIN_8453_YO_USD_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CHAIN8453YOUSDVAULT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CHAIN_8453_YO_USD_VAULT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CHAIN8453YOUSDVAULT is a free data retrieval call binding the contract method 0x8753565f.
//
// Solidity: function CHAIN_8453_YO_USD_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CHAIN8453YOUSDVAULT() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453YOUSDVAULT(&_AcrossV3AdapterTest.CallOpts)
}

// CHAIN8453YOUSDVAULT is a free data retrieval call binding the contract method 0x8753565f.
//
// Solidity: function CHAIN_8453_YO_USD_VAULT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CHAIN8453YOUSDVAULT() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.CHAIN8453YOUSDVAULT(&_AcrossV3AdapterTest.CallOpts)
}

// CLAIMCANCELDEPOSITREQUEST7540HOOKKEY is a free data retrieval call binding the contract method 0xa511d386.
//
// Solidity: function CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CLAIMCANCELDEPOSITREQUEST7540HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// CLAIMCANCELDEPOSITREQUEST7540HOOKKEY is a free data retrieval call binding the contract method 0xa511d386.
//
// Solidity: function CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CLAIMCANCELDEPOSITREQUEST7540HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.CLAIMCANCELDEPOSITREQUEST7540HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// CLAIMCANCELDEPOSITREQUEST7540HOOKKEY is a free data retrieval call binding the contract method 0xa511d386.
//
// Solidity: function CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CLAIMCANCELDEPOSITREQUEST7540HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.CLAIMCANCELDEPOSITREQUEST7540HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// CLAIMCANCELREDEEMREQUEST7540HOOKKEY is a free data retrieval call binding the contract method 0xe994b12a.
//
// Solidity: function CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) CLAIMCANCELREDEEMREQUEST7540HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// CLAIMCANCELREDEEMREQUEST7540HOOKKEY is a free data retrieval call binding the contract method 0xe994b12a.
//
// Solidity: function CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) CLAIMCANCELREDEEMREQUEST7540HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.CLAIMCANCELREDEEMREQUEST7540HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// CLAIMCANCELREDEEMREQUEST7540HOOKKEY is a free data retrieval call binding the contract method 0xe994b12a.
//
// Solidity: function CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) CLAIMCANCELREDEEMREQUEST7540HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.CLAIMCANCELREDEEMREQUEST7540HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// DAIKEY is a free data retrieval call binding the contract method 0xd0cbbf75.
//
// Solidity: function DAI_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) DAIKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "DAI_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// DAIKEY is a free data retrieval call binding the contract method 0xd0cbbf75.
//
// Solidity: function DAI_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) DAIKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.DAIKEY(&_AcrossV3AdapterTest.CallOpts)
}

// DAIKEY is a free data retrieval call binding the contract method 0xd0cbbf75.
//
// Solidity: function DAI_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) DAIKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.DAIKEY(&_AcrossV3AdapterTest.CallOpts)
}

// DEBRIDGEADAPTERKEY is a free data retrieval call binding the contract method 0x3a1fd57e.
//
// Solidity: function DEBRIDGE_ADAPTER_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) DEBRIDGEADAPTERKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "DEBRIDGE_ADAPTER_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// DEBRIDGEADAPTERKEY is a free data retrieval call binding the contract method 0x3a1fd57e.
//
// Solidity: function DEBRIDGE_ADAPTER_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) DEBRIDGEADAPTERKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.DEBRIDGEADAPTERKEY(&_AcrossV3AdapterTest.CallOpts)
}

// DEBRIDGEADAPTERKEY is a free data retrieval call binding the contract method 0x3a1fd57e.
//
// Solidity: function DEBRIDGE_ADAPTER_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) DEBRIDGEADAPTERKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.DEBRIDGEADAPTERKEY(&_AcrossV3AdapterTest.CallOpts)
}

// DEBRIDGECANCELORDERHOOKKEY is a free data retrieval call binding the contract method 0xcc7603aa.
//
// Solidity: function DEBRIDGE_CANCEL_ORDER_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) DEBRIDGECANCELORDERHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "DEBRIDGE_CANCEL_ORDER_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// DEBRIDGECANCELORDERHOOKKEY is a free data retrieval call binding the contract method 0xcc7603aa.
//
// Solidity: function DEBRIDGE_CANCEL_ORDER_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) DEBRIDGECANCELORDERHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.DEBRIDGECANCELORDERHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// DEBRIDGECANCELORDERHOOKKEY is a free data retrieval call binding the contract method 0xcc7603aa.
//
// Solidity: function DEBRIDGE_CANCEL_ORDER_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) DEBRIDGECANCELORDERHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.DEBRIDGECANCELORDERHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// DEBRIDGEDLNDST is a free data retrieval call binding the contract method 0x1458a73f.
//
// Solidity: function DEBRIDGE_DLN_DST() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) DEBRIDGEDLNDST(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "DEBRIDGE_DLN_DST")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// DEBRIDGEDLNDST is a free data retrieval call binding the contract method 0x1458a73f.
//
// Solidity: function DEBRIDGE_DLN_DST() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) DEBRIDGEDLNDST() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.DEBRIDGEDLNDST(&_AcrossV3AdapterTest.CallOpts)
}

// DEBRIDGEDLNDST is a free data retrieval call binding the contract method 0x1458a73f.
//
// Solidity: function DEBRIDGE_DLN_DST() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) DEBRIDGEDLNDST() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.DEBRIDGEDLNDST(&_AcrossV3AdapterTest.CallOpts)
}

// DEBRIDGEDLNHELPERKEY is a free data retrieval call binding the contract method 0xaa54f472.
//
// Solidity: function DEBRIDGE_DLN_HELPER_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) DEBRIDGEDLNHELPERKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "DEBRIDGE_DLN_HELPER_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// DEBRIDGEDLNHELPERKEY is a free data retrieval call binding the contract method 0xaa54f472.
//
// Solidity: function DEBRIDGE_DLN_HELPER_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) DEBRIDGEDLNHELPERKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.DEBRIDGEDLNHELPERKEY(&_AcrossV3AdapterTest.CallOpts)
}

// DEBRIDGEDLNHELPERKEY is a free data retrieval call binding the contract method 0xaa54f472.
//
// Solidity: function DEBRIDGE_DLN_HELPER_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) DEBRIDGEDLNHELPERKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.DEBRIDGEDLNHELPERKEY(&_AcrossV3AdapterTest.CallOpts)
}

// DEBRIDGEDLNSOURCEADDRESS is a free data retrieval call binding the contract method 0x59564f70.
//
// Solidity: function DEBRIDGE_DLN_SOURCE_ADDRESS() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) DEBRIDGEDLNSOURCEADDRESS(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "DEBRIDGE_DLN_SOURCE_ADDRESS")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// DEBRIDGEDLNSOURCEADDRESS is a free data retrieval call binding the contract method 0x59564f70.
//
// Solidity: function DEBRIDGE_DLN_SOURCE_ADDRESS() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) DEBRIDGEDLNSOURCEADDRESS() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.DEBRIDGEDLNSOURCEADDRESS(&_AcrossV3AdapterTest.CallOpts)
}

// DEBRIDGEDLNSOURCEADDRESS is a free data retrieval call binding the contract method 0x59564f70.
//
// Solidity: function DEBRIDGE_DLN_SOURCE_ADDRESS() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) DEBRIDGEDLNSOURCEADDRESS() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.DEBRIDGEDLNSOURCEADDRESS(&_AcrossV3AdapterTest.CallOpts)
}

// DEBRIDGEHELPERKEY is a free data retrieval call binding the contract method 0xbdf47558.
//
// Solidity: function DEBRIDGE_HELPER_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) DEBRIDGEHELPERKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "DEBRIDGE_HELPER_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// DEBRIDGEHELPERKEY is a free data retrieval call binding the contract method 0xbdf47558.
//
// Solidity: function DEBRIDGE_HELPER_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) DEBRIDGEHELPERKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.DEBRIDGEHELPERKEY(&_AcrossV3AdapterTest.CallOpts)
}

// DEBRIDGEHELPERKEY is a free data retrieval call binding the contract method 0xbdf47558.
//
// Solidity: function DEBRIDGE_HELPER_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) DEBRIDGEHELPERKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.DEBRIDGEHELPERKEY(&_AcrossV3AdapterTest.CallOpts)
}

// DEBRIDGESENDORDERANDEXECUTEONDSTHOOKKEY is a free data retrieval call binding the contract method 0x56769a9c.
//
// Solidity: function DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) DEBRIDGESENDORDERANDEXECUTEONDSTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// DEBRIDGESENDORDERANDEXECUTEONDSTHOOKKEY is a free data retrieval call binding the contract method 0x56769a9c.
//
// Solidity: function DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) DEBRIDGESENDORDERANDEXECUTEONDSTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.DEBRIDGESENDORDERANDEXECUTEONDSTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// DEBRIDGESENDORDERANDEXECUTEONDSTHOOKKEY is a free data retrieval call binding the contract method 0x56769a9c.
//
// Solidity: function DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) DEBRIDGESENDORDERANDEXECUTEONDSTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.DEBRIDGESENDORDERANDEXECUTEONDSTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// DEPOSIT4626VAULTHOOKKEY is a free data retrieval call binding the contract method 0x4d0c825d.
//
// Solidity: function DEPOSIT_4626_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) DEPOSIT4626VAULTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "DEPOSIT_4626_VAULT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// DEPOSIT4626VAULTHOOKKEY is a free data retrieval call binding the contract method 0x4d0c825d.
//
// Solidity: function DEPOSIT_4626_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) DEPOSIT4626VAULTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.DEPOSIT4626VAULTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// DEPOSIT4626VAULTHOOKKEY is a free data retrieval call binding the contract method 0x4d0c825d.
//
// Solidity: function DEPOSIT_4626_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) DEPOSIT4626VAULTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.DEPOSIT4626VAULTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// DEPOSIT5115VAULTHOOKKEY is a free data retrieval call binding the contract method 0x0ed4cb5d.
//
// Solidity: function DEPOSIT_5115_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) DEPOSIT5115VAULTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "DEPOSIT_5115_VAULT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// DEPOSIT5115VAULTHOOKKEY is a free data retrieval call binding the contract method 0x0ed4cb5d.
//
// Solidity: function DEPOSIT_5115_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) DEPOSIT5115VAULTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.DEPOSIT5115VAULTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// DEPOSIT5115VAULTHOOKKEY is a free data retrieval call binding the contract method 0x0ed4cb5d.
//
// Solidity: function DEPOSIT_5115_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) DEPOSIT5115VAULTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.DEPOSIT5115VAULTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// DEPOSIT7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x6e53b637.
//
// Solidity: function DEPOSIT_7540_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) DEPOSIT7540VAULTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "DEPOSIT_7540_VAULT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// DEPOSIT7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x6e53b637.
//
// Solidity: function DEPOSIT_7540_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) DEPOSIT7540VAULTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.DEPOSIT7540VAULTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// DEPOSIT7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x6e53b637.
//
// Solidity: function DEPOSIT_7540_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) DEPOSIT7540VAULTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.DEPOSIT7540VAULTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ENTRYPOINTADDR is a free data retrieval call binding the contract method 0xc4bb9a07.
//
// Solidity: function ENTRYPOINT_ADDR() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ENTRYPOINTADDR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ENTRYPOINT_ADDR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// ENTRYPOINTADDR is a free data retrieval call binding the contract method 0xc4bb9a07.
//
// Solidity: function ENTRYPOINT_ADDR() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ENTRYPOINTADDR() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.ENTRYPOINTADDR(&_AcrossV3AdapterTest.CallOpts)
}

// ENTRYPOINTADDR is a free data retrieval call binding the contract method 0xc4bb9a07.
//
// Solidity: function ENTRYPOINT_ADDR() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ENTRYPOINTADDR() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.ENTRYPOINTADDR(&_AcrossV3AdapterTest.CallOpts)
}

// ERC1155LEDGERKEY is a free data retrieval call binding the contract method 0x0995c88b.
//
// Solidity: function ERC1155_LEDGER_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ERC1155LEDGERKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ERC1155_LEDGER_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ERC1155LEDGERKEY is a free data retrieval call binding the contract method 0x0995c88b.
//
// Solidity: function ERC1155_LEDGER_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ERC1155LEDGERKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ERC1155LEDGERKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ERC1155LEDGERKEY is a free data retrieval call binding the contract method 0x0995c88b.
//
// Solidity: function ERC1155_LEDGER_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ERC1155LEDGERKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ERC1155LEDGERKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ERC4626VAULTKEY is a free data retrieval call binding the contract method 0x59c528f6.
//
// Solidity: function ERC4626_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ERC4626VAULTKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ERC4626_VAULT_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ERC4626VAULTKEY is a free data retrieval call binding the contract method 0x59c528f6.
//
// Solidity: function ERC4626_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ERC4626VAULTKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ERC4626VAULTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ERC4626VAULTKEY is a free data retrieval call binding the contract method 0x59c528f6.
//
// Solidity: function ERC4626_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ERC4626VAULTKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ERC4626VAULTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ERC4626YIELDSOURCEORACLEKEY is a free data retrieval call binding the contract method 0x3a58da28.
//
// Solidity: function ERC4626_YIELD_SOURCE_ORACLE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ERC4626YIELDSOURCEORACLEKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ERC4626_YIELD_SOURCE_ORACLE_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ERC4626YIELDSOURCEORACLEKEY is a free data retrieval call binding the contract method 0x3a58da28.
//
// Solidity: function ERC4626_YIELD_SOURCE_ORACLE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ERC4626YIELDSOURCEORACLEKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ERC4626YIELDSOURCEORACLEKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ERC4626YIELDSOURCEORACLEKEY is a free data retrieval call binding the contract method 0x3a58da28.
//
// Solidity: function ERC4626_YIELD_SOURCE_ORACLE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ERC4626YIELDSOURCEORACLEKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ERC4626YIELDSOURCEORACLEKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ERC5115VAULTKEY is a free data retrieval call binding the contract method 0xa85353bc.
//
// Solidity: function ERC5115_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ERC5115VAULTKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ERC5115_VAULT_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ERC5115VAULTKEY is a free data retrieval call binding the contract method 0xa85353bc.
//
// Solidity: function ERC5115_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ERC5115VAULTKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ERC5115VAULTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ERC5115VAULTKEY is a free data retrieval call binding the contract method 0xa85353bc.
//
// Solidity: function ERC5115_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ERC5115VAULTKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ERC5115VAULTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ERC5115YIELDSOURCEORACLEKEY is a free data retrieval call binding the contract method 0x4329fe83.
//
// Solidity: function ERC5115_YIELD_SOURCE_ORACLE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ERC5115YIELDSOURCEORACLEKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ERC5115_YIELD_SOURCE_ORACLE_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ERC5115YIELDSOURCEORACLEKEY is a free data retrieval call binding the contract method 0x4329fe83.
//
// Solidity: function ERC5115_YIELD_SOURCE_ORACLE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ERC5115YIELDSOURCEORACLEKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ERC5115YIELDSOURCEORACLEKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ERC5115YIELDSOURCEORACLEKEY is a free data retrieval call binding the contract method 0x4329fe83.
//
// Solidity: function ERC5115_YIELD_SOURCE_ORACLE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ERC5115YIELDSOURCEORACLEKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ERC5115YIELDSOURCEORACLEKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ERC7540FULLYASYNCKEY is a free data retrieval call binding the contract method 0x665c8fb6.
//
// Solidity: function ERC7540_FULLY_ASYNC_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ERC7540FULLYASYNCKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ERC7540_FULLY_ASYNC_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ERC7540FULLYASYNCKEY is a free data retrieval call binding the contract method 0x665c8fb6.
//
// Solidity: function ERC7540_FULLY_ASYNC_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ERC7540FULLYASYNCKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ERC7540FULLYASYNCKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ERC7540FULLYASYNCKEY is a free data retrieval call binding the contract method 0x665c8fb6.
//
// Solidity: function ERC7540_FULLY_ASYNC_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ERC7540FULLYASYNCKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ERC7540FULLYASYNCKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ERC7540YIELDSOURCEORACLEKEY is a free data retrieval call binding the contract method 0x68f007a2.
//
// Solidity: function ERC7540_YIELD_SOURCE_ORACLE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ERC7540YIELDSOURCEORACLEKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ERC7540_YIELD_SOURCE_ORACLE_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ERC7540YIELDSOURCEORACLEKEY is a free data retrieval call binding the contract method 0x68f007a2.
//
// Solidity: function ERC7540_YIELD_SOURCE_ORACLE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ERC7540YIELDSOURCEORACLEKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ERC7540YIELDSOURCEORACLEKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ERC7540YIELDSOURCEORACLEKEY is a free data retrieval call binding the contract method 0x68f007a2.
//
// Solidity: function ERC7540_YIELD_SOURCE_ORACLE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ERC7540YIELDSOURCEORACLEKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ERC7540YIELDSOURCEORACLEKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ETH is a free data retrieval call binding the contract method 0x8322fff2.
//
// Solidity: function ETH() view returns(uint64)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ETH(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ETH")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// ETH is a free data retrieval call binding the contract method 0x8322fff2.
//
// Solidity: function ETH() view returns(uint64)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ETH() (uint64, error) {
	return _AcrossV3AdapterTest.Contract.ETH(&_AcrossV3AdapterTest.CallOpts)
}

// ETH is a free data retrieval call binding the contract method 0x8322fff2.
//
// Solidity: function ETH() view returns(uint64)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ETH() (uint64, error) {
	return _AcrossV3AdapterTest.Contract.ETH(&_AcrossV3AdapterTest.CallOpts)
}

// ETHENACOOLDOWNSHARESHOOKKEY is a free data retrieval call binding the contract method 0xcd4a8067.
//
// Solidity: function ETHENA_COOLDOWN_SHARES_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ETHENACOOLDOWNSHARESHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ETHENA_COOLDOWN_SHARES_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ETHENACOOLDOWNSHARESHOOKKEY is a free data retrieval call binding the contract method 0xcd4a8067.
//
// Solidity: function ETHENA_COOLDOWN_SHARES_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ETHENACOOLDOWNSHARESHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ETHENACOOLDOWNSHARESHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ETHENACOOLDOWNSHARESHOOKKEY is a free data retrieval call binding the contract method 0xcd4a8067.
//
// Solidity: function ETHENA_COOLDOWN_SHARES_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ETHENACOOLDOWNSHARESHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ETHENACOOLDOWNSHARESHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ETHENAUNSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xec774bfe.
//
// Solidity: function ETHENA_UNSTAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ETHENAUNSTAKEHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ETHENA_UNSTAKE_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ETHENAUNSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xec774bfe.
//
// Solidity: function ETHENA_UNSTAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ETHENAUNSTAKEHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ETHENAUNSTAKEHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ETHENAUNSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xec774bfe.
//
// Solidity: function ETHENA_UNSTAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ETHENAUNSTAKEHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ETHENAUNSTAKEHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ETHEREUMKEY is a free data retrieval call binding the contract method 0xe65d37f7.
//
// Solidity: function ETHEREUM_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ETHEREUMKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ETHEREUM_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ETHEREUMKEY is a free data retrieval call binding the contract method 0xe65d37f7.
//
// Solidity: function ETHEREUM_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ETHEREUMKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ETHEREUMKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ETHEREUMKEY is a free data retrieval call binding the contract method 0xe65d37f7.
//
// Solidity: function ETHEREUM_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ETHEREUMKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ETHEREUMKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ETHEREUMRPCURLKEY is a free data retrieval call binding the contract method 0x6091ca77.
//
// Solidity: function ETHEREUM_RPC_URL_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ETHEREUMRPCURLKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ETHEREUM_RPC_URL_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ETHEREUMRPCURLKEY is a free data retrieval call binding the contract method 0x6091ca77.
//
// Solidity: function ETHEREUM_RPC_URL_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ETHEREUMRPCURLKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ETHEREUMRPCURLKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ETHEREUMRPCURLKEY is a free data retrieval call binding the contract method 0x6091ca77.
//
// Solidity: function ETHEREUM_RPC_URL_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ETHEREUMRPCURLKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ETHEREUMRPCURLKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ETHBLOCK is a free data retrieval call binding the contract method 0x007e92d0.
//
// Solidity: function ETH_BLOCK() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ETHBLOCK(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ETH_BLOCK")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// ETHBLOCK is a free data retrieval call binding the contract method 0x007e92d0.
//
// Solidity: function ETH_BLOCK() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ETHBLOCK() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.ETHBLOCK(&_AcrossV3AdapterTest.CallOpts)
}

// ETHBLOCK is a free data retrieval call binding the contract method 0x007e92d0.
//
// Solidity: function ETH_BLOCK() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ETHBLOCK() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.ETHBLOCK(&_AcrossV3AdapterTest.CallOpts)
}

// EULERVAULTKEY is a free data retrieval call binding the contract method 0x98b32718.
//
// Solidity: function EULER_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) EULERVAULTKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "EULER_VAULT_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// EULERVAULTKEY is a free data retrieval call binding the contract method 0x98b32718.
//
// Solidity: function EULER_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) EULERVAULTKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.EULERVAULTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// EULERVAULTKEY is a free data retrieval call binding the contract method 0x98b32718.
//
// Solidity: function EULER_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) EULERVAULTKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.EULERVAULTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// EXTRALARGE is a free data retrieval call binding the contract method 0x2038afcf.
//
// Solidity: function EXTRA_LARGE() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) EXTRALARGE(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "EXTRA_LARGE")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// EXTRALARGE is a free data retrieval call binding the contract method 0x2038afcf.
//
// Solidity: function EXTRA_LARGE() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) EXTRALARGE() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.EXTRALARGE(&_AcrossV3AdapterTest.CallOpts)
}

// EXTRALARGE is a free data retrieval call binding the contract method 0x2038afcf.
//
// Solidity: function EXTRA_LARGE() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) EXTRALARGE() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.EXTRALARGE(&_AcrossV3AdapterTest.CallOpts)
}

// FEERECIPIENTKEY is a free data retrieval call binding the contract method 0x0f4924f4.
//
// Solidity: function FEE_RECIPIENT_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) FEERECIPIENTKEY(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "FEE_RECIPIENT_KEY")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// FEERECIPIENTKEY is a free data retrieval call binding the contract method 0x0f4924f4.
//
// Solidity: function FEE_RECIPIENT_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) FEERECIPIENTKEY() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.FEERECIPIENTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// FEERECIPIENTKEY is a free data retrieval call binding the contract method 0x0f4924f4.
//
// Solidity: function FEE_RECIPIENT_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) FEERECIPIENTKEY() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.FEERECIPIENTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// FLAREALGEBRAINTEGRALSWAPROUTER is a free data retrieval call binding the contract method 0x866898e2.
//
// Solidity: function FLARE_ALGEBRA_INTEGRAL_SWAP_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) FLAREALGEBRAINTEGRALSWAPROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "FLARE_ALGEBRA_INTEGRAL_SWAP_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// FLAREALGEBRAINTEGRALSWAPROUTER is a free data retrieval call binding the contract method 0x866898e2.
//
// Solidity: function FLARE_ALGEBRA_INTEGRAL_SWAP_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) FLAREALGEBRAINTEGRALSWAPROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.FLAREALGEBRAINTEGRALSWAPROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// FLAREALGEBRAINTEGRALSWAPROUTER is a free data retrieval call binding the contract method 0x866898e2.
//
// Solidity: function FLARE_ALGEBRA_INTEGRAL_SWAP_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) FLAREALGEBRAINTEGRALSWAPROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.FLAREALGEBRAINTEGRALSWAPROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// FLAREALGEBRAPOOLDEPLOYER is a free data retrieval call binding the contract method 0x6be0daeb.
//
// Solidity: function FLARE_ALGEBRA_POOL_DEPLOYER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) FLAREALGEBRAPOOLDEPLOYER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "FLARE_ALGEBRA_POOL_DEPLOYER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// FLAREALGEBRAPOOLDEPLOYER is a free data retrieval call binding the contract method 0x6be0daeb.
//
// Solidity: function FLARE_ALGEBRA_POOL_DEPLOYER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) FLAREALGEBRAPOOLDEPLOYER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.FLAREALGEBRAPOOLDEPLOYER(&_AcrossV3AdapterTest.CallOpts)
}

// FLAREALGEBRAPOOLDEPLOYER is a free data retrieval call binding the contract method 0x6be0daeb.
//
// Solidity: function FLARE_ALGEBRA_POOL_DEPLOYER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) FLAREALGEBRAPOOLDEPLOYER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.FLAREALGEBRAPOOLDEPLOYER(&_AcrossV3AdapterTest.CallOpts)
}

// FLARERNAT is a free data retrieval call binding the contract method 0x8b94e9e6.
//
// Solidity: function FLARE_RNAT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) FLARERNAT(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "FLARE_RNAT")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// FLARERNAT is a free data retrieval call binding the contract method 0x8b94e9e6.
//
// Solidity: function FLARE_RNAT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) FLARERNAT() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.FLARERNAT(&_AcrossV3AdapterTest.CallOpts)
}

// FLARERNAT is a free data retrieval call binding the contract method 0x8b94e9e6.
//
// Solidity: function FLARE_RNAT() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) FLARERNAT() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.FLARERNAT(&_AcrossV3AdapterTest.CallOpts)
}

// FLARESFLR is a free data retrieval call binding the contract method 0xdfe1a5c0.
//
// Solidity: function FLARE_SFLR() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) FLARESFLR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "FLARE_SFLR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// FLARESFLR is a free data retrieval call binding the contract method 0xdfe1a5c0.
//
// Solidity: function FLARE_SFLR() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) FLARESFLR() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.FLARESFLR(&_AcrossV3AdapterTest.CallOpts)
}

// FLARESFLR is a free data retrieval call binding the contract method 0xdfe1a5c0.
//
// Solidity: function FLARE_SFLR() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) FLARESFLR() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.FLARESFLR(&_AcrossV3AdapterTest.CallOpts)
}

// FLARESPRK is a free data retrieval call binding the contract method 0x0813e2e6.
//
// Solidity: function FLARE_SPRK() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) FLARESPRK(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "FLARE_SPRK")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// FLARESPRK is a free data retrieval call binding the contract method 0x0813e2e6.
//
// Solidity: function FLARE_SPRK() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) FLARESPRK() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.FLARESPRK(&_AcrossV3AdapterTest.CallOpts)
}

// FLARESPRK is a free data retrieval call binding the contract method 0x0813e2e6.
//
// Solidity: function FLARE_SPRK() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) FLARESPRK() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.FLARESPRK(&_AcrossV3AdapterTest.CallOpts)
}

// FLAREWFLR is a free data retrieval call binding the contract method 0x40602604.
//
// Solidity: function FLARE_WFLR() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) FLAREWFLR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "FLARE_WFLR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// FLAREWFLR is a free data retrieval call binding the contract method 0x40602604.
//
// Solidity: function FLARE_WFLR() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) FLAREWFLR() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.FLAREWFLR(&_AcrossV3AdapterTest.CallOpts)
}

// FLAREWFLR is a free data retrieval call binding the contract method 0x40602604.
//
// Solidity: function FLARE_WFLR() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) FLAREWFLR() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.FLAREWFLR(&_AcrossV3AdapterTest.CallOpts)
}

// FLUIDCLAIMREWARDHOOKKEY is a free data retrieval call binding the contract method 0x7f927cda.
//
// Solidity: function FLUID_CLAIM_REWARD_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) FLUIDCLAIMREWARDHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "FLUID_CLAIM_REWARD_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// FLUIDCLAIMREWARDHOOKKEY is a free data retrieval call binding the contract method 0x7f927cda.
//
// Solidity: function FLUID_CLAIM_REWARD_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) FLUIDCLAIMREWARDHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.FLUIDCLAIMREWARDHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// FLUIDCLAIMREWARDHOOKKEY is a free data retrieval call binding the contract method 0x7f927cda.
//
// Solidity: function FLUID_CLAIM_REWARD_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) FLUIDCLAIMREWARDHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.FLUIDCLAIMREWARDHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// FLUIDSTAKEHOOKKEY is a free data retrieval call binding the contract method 0x66892cf0.
//
// Solidity: function FLUID_STAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) FLUIDSTAKEHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "FLUID_STAKE_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// FLUIDSTAKEHOOKKEY is a free data retrieval call binding the contract method 0x66892cf0.
//
// Solidity: function FLUID_STAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) FLUIDSTAKEHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.FLUIDSTAKEHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// FLUIDSTAKEHOOKKEY is a free data retrieval call binding the contract method 0x66892cf0.
//
// Solidity: function FLUID_STAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) FLUIDSTAKEHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.FLUIDSTAKEHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// FLUIDUNSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xe1d36abb.
//
// Solidity: function FLUID_UNSTAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) FLUIDUNSTAKEHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "FLUID_UNSTAKE_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// FLUIDUNSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xe1d36abb.
//
// Solidity: function FLUID_UNSTAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) FLUIDUNSTAKEHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.FLUIDUNSTAKEHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// FLUIDUNSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xe1d36abb.
//
// Solidity: function FLUID_UNSTAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) FLUIDUNSTAKEHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.FLUIDUNSTAKEHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// FLUIDVAULTKEY is a free data retrieval call binding the contract method 0x498005f7.
//
// Solidity: function FLUID_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) FLUIDVAULTKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "FLUID_VAULT_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// FLUIDVAULTKEY is a free data retrieval call binding the contract method 0x498005f7.
//
// Solidity: function FLUID_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) FLUIDVAULTKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.FLUIDVAULTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// FLUIDVAULTKEY is a free data retrieval call binding the contract method 0x498005f7.
//
// Solidity: function FLUID_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) FLUIDVAULTKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.FLUIDVAULTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// GEARBOXAPPROVEANDSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xa4b5a5f8.
//
// Solidity: function GEARBOX_APPROVE_AND_STAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) GEARBOXAPPROVEANDSTAKEHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "GEARBOX_APPROVE_AND_STAKE_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// GEARBOXAPPROVEANDSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xa4b5a5f8.
//
// Solidity: function GEARBOX_APPROVE_AND_STAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) GEARBOXAPPROVEANDSTAKEHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.GEARBOXAPPROVEANDSTAKEHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// GEARBOXAPPROVEANDSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xa4b5a5f8.
//
// Solidity: function GEARBOX_APPROVE_AND_STAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) GEARBOXAPPROVEANDSTAKEHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.GEARBOXAPPROVEANDSTAKEHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// GEARBOXCLAIMREWARDHOOKKEY is a free data retrieval call binding the contract method 0x5e101704.
//
// Solidity: function GEARBOX_CLAIM_REWARD_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) GEARBOXCLAIMREWARDHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "GEARBOX_CLAIM_REWARD_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// GEARBOXCLAIMREWARDHOOKKEY is a free data retrieval call binding the contract method 0x5e101704.
//
// Solidity: function GEARBOX_CLAIM_REWARD_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) GEARBOXCLAIMREWARDHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.GEARBOXCLAIMREWARDHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// GEARBOXCLAIMREWARDHOOKKEY is a free data retrieval call binding the contract method 0x5e101704.
//
// Solidity: function GEARBOX_CLAIM_REWARD_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) GEARBOXCLAIMREWARDHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.GEARBOXCLAIMREWARDHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// GEARBOXSTAKEHOOKKEY is a free data retrieval call binding the contract method 0x9a14bb34.
//
// Solidity: function GEARBOX_STAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) GEARBOXSTAKEHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "GEARBOX_STAKE_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// GEARBOXSTAKEHOOKKEY is a free data retrieval call binding the contract method 0x9a14bb34.
//
// Solidity: function GEARBOX_STAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) GEARBOXSTAKEHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.GEARBOXSTAKEHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// GEARBOXSTAKEHOOKKEY is a free data retrieval call binding the contract method 0x9a14bb34.
//
// Solidity: function GEARBOX_STAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) GEARBOXSTAKEHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.GEARBOXSTAKEHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// GEARBOXSTAKINGKEY is a free data retrieval call binding the contract method 0x96c407c4.
//
// Solidity: function GEARBOX_STAKING_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) GEARBOXSTAKINGKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "GEARBOX_STAKING_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// GEARBOXSTAKINGKEY is a free data retrieval call binding the contract method 0x96c407c4.
//
// Solidity: function GEARBOX_STAKING_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) GEARBOXSTAKINGKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.GEARBOXSTAKINGKEY(&_AcrossV3AdapterTest.CallOpts)
}

// GEARBOXSTAKINGKEY is a free data retrieval call binding the contract method 0x96c407c4.
//
// Solidity: function GEARBOX_STAKING_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) GEARBOXSTAKINGKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.GEARBOXSTAKINGKEY(&_AcrossV3AdapterTest.CallOpts)
}

// GEARBOXUNSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xf858de50.
//
// Solidity: function GEARBOX_UNSTAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) GEARBOXUNSTAKEHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "GEARBOX_UNSTAKE_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// GEARBOXUNSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xf858de50.
//
// Solidity: function GEARBOX_UNSTAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) GEARBOXUNSTAKEHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.GEARBOXUNSTAKEHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// GEARBOXUNSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xf858de50.
//
// Solidity: function GEARBOX_UNSTAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) GEARBOXUNSTAKEHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.GEARBOXUNSTAKEHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// GEARBOXVAULTKEY is a free data retrieval call binding the contract method 0xed385855.
//
// Solidity: function GEARBOX_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) GEARBOXVAULTKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "GEARBOX_VAULT_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// GEARBOXVAULTKEY is a free data retrieval call binding the contract method 0xed385855.
//
// Solidity: function GEARBOX_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) GEARBOXVAULTKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.GEARBOXVAULTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// GEARBOXVAULTKEY is a free data retrieval call binding the contract method 0xed385855.
//
// Solidity: function GEARBOX_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) GEARBOXVAULTKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.GEARBOXVAULTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// GEARKEY is a free data retrieval call binding the contract method 0xcb21fd61.
//
// Solidity: function GEAR_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) GEARKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "GEAR_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// GEARKEY is a free data retrieval call binding the contract method 0xcb21fd61.
//
// Solidity: function GEAR_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) GEARKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.GEARKEY(&_AcrossV3AdapterTest.CallOpts)
}

// GEARKEY is a free data retrieval call binding the contract method 0xcb21fd61.
//
// Solidity: function GEAR_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) GEARKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.GEARKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ISTEST is a free data retrieval call binding the contract method 0xfa7626d4.
//
// Solidity: function IS_TEST() view returns(bool)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ISTEST(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "IS_TEST")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// ISTEST is a free data retrieval call binding the contract method 0xfa7626d4.
//
// Solidity: function IS_TEST() view returns(bool)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ISTEST() (bool, error) {
	return _AcrossV3AdapterTest.Contract.ISTEST(&_AcrossV3AdapterTest.CallOpts)
}

// ISTEST is a free data retrieval call binding the contract method 0xfa7626d4.
//
// Solidity: function IS_TEST() view returns(bool)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ISTEST() (bool, error) {
	return _AcrossV3AdapterTest.Contract.ISTEST(&_AcrossV3AdapterTest.CallOpts)
}

// LARGE is a free data retrieval call binding the contract method 0xaed9a992.
//
// Solidity: function LARGE() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) LARGE(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "LARGE")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// LARGE is a free data retrieval call binding the contract method 0xaed9a992.
//
// Solidity: function LARGE() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) LARGE() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.LARGE(&_AcrossV3AdapterTest.CallOpts)
}

// LARGE is a free data retrieval call binding the contract method 0xaed9a992.
//
// Solidity: function LARGE() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) LARGE() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.LARGE(&_AcrossV3AdapterTest.CallOpts)
}

// MAINNETV2SWAPROUTER is a free data retrieval call binding the contract method 0x591431c0.
//
// Solidity: function MAINNET_V2_SWAP_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MAINNETV2SWAPROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MAINNET_V2_SWAP_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MAINNETV2SWAPROUTER is a free data retrieval call binding the contract method 0x591431c0.
//
// Solidity: function MAINNET_V2_SWAP_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MAINNETV2SWAPROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MAINNETV2SWAPROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// MAINNETV2SWAPROUTER is a free data retrieval call binding the contract method 0x591431c0.
//
// Solidity: function MAINNET_V2_SWAP_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MAINNETV2SWAPROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MAINNETV2SWAPROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// MAINNETV3SWAPROUTER is a free data retrieval call binding the contract method 0x6db42269.
//
// Solidity: function MAINNET_V3_SWAP_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MAINNETV3SWAPROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MAINNET_V3_SWAP_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MAINNETV3SWAPROUTER is a free data retrieval call binding the contract method 0x6db42269.
//
// Solidity: function MAINNET_V3_SWAP_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MAINNETV3SWAPROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MAINNETV3SWAPROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// MAINNETV3SWAPROUTER is a free data retrieval call binding the contract method 0x6db42269.
//
// Solidity: function MAINNET_V3_SWAP_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MAINNETV3SWAPROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MAINNETV3SWAPROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// MAINNETV3SWAPROUTER02 is a free data retrieval call binding the contract method 0x11f0e9ee.
//
// Solidity: function MAINNET_V3_SWAP_ROUTER_02() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MAINNETV3SWAPROUTER02(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MAINNET_V3_SWAP_ROUTER_02")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MAINNETV3SWAPROUTER02 is a free data retrieval call binding the contract method 0x11f0e9ee.
//
// Solidity: function MAINNET_V3_SWAP_ROUTER_02() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MAINNETV3SWAPROUTER02() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MAINNETV3SWAPROUTER02(&_AcrossV3AdapterTest.CallOpts)
}

// MAINNETV3SWAPROUTER02 is a free data retrieval call binding the contract method 0x11f0e9ee.
//
// Solidity: function MAINNET_V3_SWAP_ROUTER_02() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MAINNETV3SWAPROUTER02() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MAINNETV3SWAPROUTER02(&_AcrossV3AdapterTest.CallOpts)
}

// MAINNETV4POOLMANAGER is a free data retrieval call binding the contract method 0xdffb1fe2.
//
// Solidity: function MAINNET_V4_POOL_MANAGER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MAINNETV4POOLMANAGER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MAINNET_V4_POOL_MANAGER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MAINNETV4POOLMANAGER is a free data retrieval call binding the contract method 0xdffb1fe2.
//
// Solidity: function MAINNET_V4_POOL_MANAGER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MAINNETV4POOLMANAGER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MAINNETV4POOLMANAGER(&_AcrossV3AdapterTest.CallOpts)
}

// MAINNETV4POOLMANAGER is a free data retrieval call binding the contract method 0xdffb1fe2.
//
// Solidity: function MAINNET_V4_POOL_MANAGER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MAINNETV4POOLMANAGER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MAINNETV4POOLMANAGER(&_AcrossV3AdapterTest.CallOpts)
}

// MAINNETV4POSITIONMANAGER is a free data retrieval call binding the contract method 0xee649c5d.
//
// Solidity: function MAINNET_V4_POSITION_MANAGER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MAINNETV4POSITIONMANAGER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MAINNET_V4_POSITION_MANAGER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MAINNETV4POSITIONMANAGER is a free data retrieval call binding the contract method 0xee649c5d.
//
// Solidity: function MAINNET_V4_POSITION_MANAGER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MAINNETV4POSITIONMANAGER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MAINNETV4POSITIONMANAGER(&_AcrossV3AdapterTest.CallOpts)
}

// MAINNETV4POSITIONMANAGER is a free data retrieval call binding the contract method 0xee649c5d.
//
// Solidity: function MAINNET_V4_POSITION_MANAGER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MAINNETV4POSITIONMANAGER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MAINNETV4POSITIONMANAGER(&_AcrossV3AdapterTest.CallOpts)
}

// MANAGER is a free data retrieval call binding the contract method 0x1b2df850.
//
// Solidity: function MANAGER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MANAGER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MANAGER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MANAGER is a free data retrieval call binding the contract method 0x1b2df850.
//
// Solidity: function MANAGER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MANAGER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MANAGER(&_AcrossV3AdapterTest.CallOpts)
}

// MANAGER is a free data retrieval call binding the contract method 0x1b2df850.
//
// Solidity: function MANAGER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MANAGER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MANAGER(&_AcrossV3AdapterTest.CallOpts)
}

// MANAGERKEY is a free data retrieval call binding the contract method 0x97d94ca0.
//
// Solidity: function MANAGER_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MANAGERKEY(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MANAGER_KEY")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// MANAGERKEY is a free data retrieval call binding the contract method 0x97d94ca0.
//
// Solidity: function MANAGER_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MANAGERKEY() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.MANAGERKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MANAGERKEY is a free data retrieval call binding the contract method 0x97d94ca0.
//
// Solidity: function MANAGER_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MANAGERKEY() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.MANAGERKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MARKROOTASUSEDHOOKKEY is a free data retrieval call binding the contract method 0x08568475.
//
// Solidity: function MARK_ROOT_AS_USED_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MARKROOTASUSEDHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MARK_ROOT_AS_USED_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MARKROOTASUSEDHOOKKEY is a free data retrieval call binding the contract method 0x08568475.
//
// Solidity: function MARK_ROOT_AS_USED_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MARKROOTASUSEDHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MARKROOTASUSEDHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MARKROOTASUSEDHOOKKEY is a free data retrieval call binding the contract method 0x08568475.
//
// Solidity: function MARK_ROOT_AS_USED_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MARKROOTASUSEDHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MARKROOTASUSEDHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MEDIUM is a free data retrieval call binding the contract method 0xedee709e.
//
// Solidity: function MEDIUM() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MEDIUM(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MEDIUM")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// MEDIUM is a free data retrieval call binding the contract method 0xedee709e.
//
// Solidity: function MEDIUM() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MEDIUM() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.MEDIUM(&_AcrossV3AdapterTest.CallOpts)
}

// MEDIUM is a free data retrieval call binding the contract method 0xedee709e.
//
// Solidity: function MEDIUM() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MEDIUM() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.MEDIUM(&_AcrossV3AdapterTest.CallOpts)
}

// MERKLCLAIMREWARDHOOKKEY is a free data retrieval call binding the contract method 0x1fb43e65.
//
// Solidity: function MERKL_CLAIM_REWARD_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MERKLCLAIMREWARDHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MERKL_CLAIM_REWARD_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MERKLCLAIMREWARDHOOKKEY is a free data retrieval call binding the contract method 0x1fb43e65.
//
// Solidity: function MERKL_CLAIM_REWARD_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MERKLCLAIMREWARDHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MERKLCLAIMREWARDHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MERKLCLAIMREWARDHOOKKEY is a free data retrieval call binding the contract method 0x1fb43e65.
//
// Solidity: function MERKL_CLAIM_REWARD_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MERKLCLAIMREWARDHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MERKLCLAIMREWARDHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MERKLDISTRIBUTOR is a free data retrieval call binding the contract method 0x219461ed.
//
// Solidity: function MERKL_DISTRIBUTOR() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MERKLDISTRIBUTOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MERKL_DISTRIBUTOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MERKLDISTRIBUTOR is a free data retrieval call binding the contract method 0x219461ed.
//
// Solidity: function MERKL_DISTRIBUTOR() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MERKLDISTRIBUTOR() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MERKLDISTRIBUTOR(&_AcrossV3AdapterTest.CallOpts)
}

// MERKLDISTRIBUTOR is a free data retrieval call binding the contract method 0x219461ed.
//
// Solidity: function MERKL_DISTRIBUTOR() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MERKLDISTRIBUTOR() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MERKLDISTRIBUTOR(&_AcrossV3AdapterTest.CallOpts)
}

// MINTSUPERPOSITIONSHOOKKEY is a free data retrieval call binding the contract method 0x206fe8a5.
//
// Solidity: function MINT_SUPERPOSITIONS_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MINTSUPERPOSITIONSHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MINT_SUPERPOSITIONS_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MINTSUPERPOSITIONSHOOKKEY is a free data retrieval call binding the contract method 0x206fe8a5.
//
// Solidity: function MINT_SUPERPOSITIONS_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MINTSUPERPOSITIONSHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MINTSUPERPOSITIONSHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MINTSUPERPOSITIONSHOOKKEY is a free data retrieval call binding the contract method 0x206fe8a5.
//
// Solidity: function MINT_SUPERPOSITIONS_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MINTSUPERPOSITIONSHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MINTSUPERPOSITIONSHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MOCKAPPROVEANDSWAPODOSHOOKKEY is a free data retrieval call binding the contract method 0x56a4d4be.
//
// Solidity: function MOCK_APPROVE_AND_SWAP_ODOS_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MOCKAPPROVEANDSWAPODOSHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MOCK_APPROVE_AND_SWAP_ODOS_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MOCKAPPROVEANDSWAPODOSHOOKKEY is a free data retrieval call binding the contract method 0x56a4d4be.
//
// Solidity: function MOCK_APPROVE_AND_SWAP_ODOS_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MOCKAPPROVEANDSWAPODOSHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MOCKAPPROVEANDSWAPODOSHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MOCKAPPROVEANDSWAPODOSHOOKKEY is a free data retrieval call binding the contract method 0x56a4d4be.
//
// Solidity: function MOCK_APPROVE_AND_SWAP_ODOS_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MOCKAPPROVEANDSWAPODOSHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MOCKAPPROVEANDSWAPODOSHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MOCKSWAPODOSHOOKKEY is a free data retrieval call binding the contract method 0x290c185f.
//
// Solidity: function MOCK_SWAP_ODOS_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MOCKSWAPODOSHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MOCK_SWAP_ODOS_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MOCKSWAPODOSHOOKKEY is a free data retrieval call binding the contract method 0x290c185f.
//
// Solidity: function MOCK_SWAP_ODOS_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MOCKSWAPODOSHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MOCKSWAPODOSHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MOCKSWAPODOSHOOKKEY is a free data retrieval call binding the contract method 0x290c185f.
//
// Solidity: function MOCK_SWAP_ODOS_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MOCKSWAPODOSHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MOCKSWAPODOSHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MOCKTARGETEXECUTORKEY is a free data retrieval call binding the contract method 0x49307462.
//
// Solidity: function MOCK_TARGET_EXECUTOR_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MOCKTARGETEXECUTORKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MOCK_TARGET_EXECUTOR_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MOCKTARGETEXECUTORKEY is a free data retrieval call binding the contract method 0x49307462.
//
// Solidity: function MOCK_TARGET_EXECUTOR_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MOCKTARGETEXECUTORKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MOCKTARGETEXECUTORKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MOCKTARGETEXECUTORKEY is a free data retrieval call binding the contract method 0x49307462.
//
// Solidity: function MOCK_TARGET_EXECUTOR_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MOCKTARGETEXECUTORKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MOCKTARGETEXECUTORKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MORPHO is a free data retrieval call binding the contract method 0x3acb5624.
//
// Solidity: function MORPHO() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MORPHO(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MORPHO")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MORPHO is a free data retrieval call binding the contract method 0x3acb5624.
//
// Solidity: function MORPHO() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MORPHO() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MORPHO(&_AcrossV3AdapterTest.CallOpts)
}

// MORPHO is a free data retrieval call binding the contract method 0x3acb5624.
//
// Solidity: function MORPHO() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MORPHO() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MORPHO(&_AcrossV3AdapterTest.CallOpts)
}

// MORPHOBORROWHOOKKEY is a free data retrieval call binding the contract method 0x35a4e139.
//
// Solidity: function MORPHO_BORROW_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MORPHOBORROWHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MORPHO_BORROW_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MORPHOBORROWHOOKKEY is a free data retrieval call binding the contract method 0x35a4e139.
//
// Solidity: function MORPHO_BORROW_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MORPHOBORROWHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MORPHOBORROWHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MORPHOBORROWHOOKKEY is a free data retrieval call binding the contract method 0x35a4e139.
//
// Solidity: function MORPHO_BORROW_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MORPHOBORROWHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MORPHOBORROWHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MORPHOGAUNTLETUSDCPRIMEKEY is a free data retrieval call binding the contract method 0x7d94dc87.
//
// Solidity: function MORPHO_GAUNTLET_USDC_PRIME_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MORPHOGAUNTLETUSDCPRIMEKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MORPHO_GAUNTLET_USDC_PRIME_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MORPHOGAUNTLETUSDCPRIMEKEY is a free data retrieval call binding the contract method 0x7d94dc87.
//
// Solidity: function MORPHO_GAUNTLET_USDC_PRIME_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MORPHOGAUNTLETUSDCPRIMEKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MORPHOGAUNTLETUSDCPRIMEKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MORPHOGAUNTLETUSDCPRIMEKEY is a free data retrieval call binding the contract method 0x7d94dc87.
//
// Solidity: function MORPHO_GAUNTLET_USDC_PRIME_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MORPHOGAUNTLETUSDCPRIMEKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MORPHOGAUNTLETUSDCPRIMEKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MORPHOGAUNTLETWETHCOREKEY is a free data retrieval call binding the contract method 0xc55a92a8.
//
// Solidity: function MORPHO_GAUNTLET_WETH_CORE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MORPHOGAUNTLETWETHCOREKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MORPHO_GAUNTLET_WETH_CORE_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MORPHOGAUNTLETWETHCOREKEY is a free data retrieval call binding the contract method 0xc55a92a8.
//
// Solidity: function MORPHO_GAUNTLET_WETH_CORE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MORPHOGAUNTLETWETHCOREKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MORPHOGAUNTLETWETHCOREKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MORPHOGAUNTLETWETHCOREKEY is a free data retrieval call binding the contract method 0xc55a92a8.
//
// Solidity: function MORPHO_GAUNTLET_WETH_CORE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MORPHOGAUNTLETWETHCOREKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MORPHOGAUNTLETWETHCOREKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MORPHOIRM is a free data retrieval call binding the contract method 0x40158af6.
//
// Solidity: function MORPHO_IRM() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MORPHOIRM(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MORPHO_IRM")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MORPHOIRM is a free data retrieval call binding the contract method 0x40158af6.
//
// Solidity: function MORPHO_IRM() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MORPHOIRM() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MORPHOIRM(&_AcrossV3AdapterTest.CallOpts)
}

// MORPHOIRM is a free data retrieval call binding the contract method 0x40158af6.
//
// Solidity: function MORPHO_IRM() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MORPHOIRM() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MORPHOIRM(&_AcrossV3AdapterTest.CallOpts)
}

// MORPHOIRMWBTCUSDC is a free data retrieval call binding the contract method 0xec788042.
//
// Solidity: function MORPHO_IRM_WBTC_USDC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MORPHOIRMWBTCUSDC(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MORPHO_IRM_WBTC_USDC")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MORPHOIRMWBTCUSDC is a free data retrieval call binding the contract method 0xec788042.
//
// Solidity: function MORPHO_IRM_WBTC_USDC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MORPHOIRMWBTCUSDC() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MORPHOIRMWBTCUSDC(&_AcrossV3AdapterTest.CallOpts)
}

// MORPHOIRMWBTCUSDC is a free data retrieval call binding the contract method 0xec788042.
//
// Solidity: function MORPHO_IRM_WBTC_USDC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MORPHOIRMWBTCUSDC() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MORPHOIRMWBTCUSDC(&_AcrossV3AdapterTest.CallOpts)
}

// MORPHOKEY is a free data retrieval call binding the contract method 0xac5e42bd.
//
// Solidity: function MORPHO_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MORPHOKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MORPHO_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MORPHOKEY is a free data retrieval call binding the contract method 0xac5e42bd.
//
// Solidity: function MORPHO_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MORPHOKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MORPHOKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MORPHOKEY is a free data retrieval call binding the contract method 0xac5e42bd.
//
// Solidity: function MORPHO_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MORPHOKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MORPHOKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MORPHOORACLE is a free data retrieval call binding the contract method 0xdfe287d3.
//
// Solidity: function MORPHO_ORACLE() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MORPHOORACLE(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MORPHO_ORACLE")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MORPHOORACLE is a free data retrieval call binding the contract method 0xdfe287d3.
//
// Solidity: function MORPHO_ORACLE() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MORPHOORACLE() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MORPHOORACLE(&_AcrossV3AdapterTest.CallOpts)
}

// MORPHOORACLE is a free data retrieval call binding the contract method 0xdfe287d3.
//
// Solidity: function MORPHO_ORACLE() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MORPHOORACLE() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MORPHOORACLE(&_AcrossV3AdapterTest.CallOpts)
}

// MORPHOORACLEWBTCUSDC is a free data retrieval call binding the contract method 0x61f02c02.
//
// Solidity: function MORPHO_ORACLE_WBTC_USDC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MORPHOORACLEWBTCUSDC(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MORPHO_ORACLE_WBTC_USDC")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MORPHOORACLEWBTCUSDC is a free data retrieval call binding the contract method 0x61f02c02.
//
// Solidity: function MORPHO_ORACLE_WBTC_USDC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MORPHOORACLEWBTCUSDC() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MORPHOORACLEWBTCUSDC(&_AcrossV3AdapterTest.CallOpts)
}

// MORPHOORACLEWBTCUSDC is a free data retrieval call binding the contract method 0x61f02c02.
//
// Solidity: function MORPHO_ORACLE_WBTC_USDC() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MORPHOORACLEWBTCUSDC() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MORPHOORACLEWBTCUSDC(&_AcrossV3AdapterTest.CallOpts)
}

// MORPHOREPAYANDWITHDRAWHOOKKEY is a free data retrieval call binding the contract method 0x7473dec6.
//
// Solidity: function MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MORPHOREPAYANDWITHDRAWHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MORPHOREPAYANDWITHDRAWHOOKKEY is a free data retrieval call binding the contract method 0x7473dec6.
//
// Solidity: function MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MORPHOREPAYANDWITHDRAWHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MORPHOREPAYANDWITHDRAWHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MORPHOREPAYANDWITHDRAWHOOKKEY is a free data retrieval call binding the contract method 0x7473dec6.
//
// Solidity: function MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MORPHOREPAYANDWITHDRAWHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MORPHOREPAYANDWITHDRAWHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MORPHOREPAYHOOKKEY is a free data retrieval call binding the contract method 0x44eaffae.
//
// Solidity: function MORPHO_REPAY_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MORPHOREPAYHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MORPHO_REPAY_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MORPHOREPAYHOOKKEY is a free data retrieval call binding the contract method 0x44eaffae.
//
// Solidity: function MORPHO_REPAY_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MORPHOREPAYHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MORPHOREPAYHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MORPHOREPAYHOOKKEY is a free data retrieval call binding the contract method 0x44eaffae.
//
// Solidity: function MORPHO_REPAY_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MORPHOREPAYHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MORPHOREPAYHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MORPHOVAULTKEY is a free data retrieval call binding the contract method 0x54fab870.
//
// Solidity: function MORPHO_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MORPHOVAULTKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "MORPHO_VAULT_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// MORPHOVAULTKEY is a free data retrieval call binding the contract method 0x54fab870.
//
// Solidity: function MORPHO_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MORPHOVAULTKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MORPHOVAULTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// MORPHOVAULTKEY is a free data retrieval call binding the contract method 0x54fab870.
//
// Solidity: function MORPHO_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MORPHOVAULTKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.MORPHOVAULTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// NEXUSACCOUNTIMPLEMENTATIONID is a free data retrieval call binding the contract method 0xe8a18c2e.
//
// Solidity: function NEXUS_ACCOUNT_IMPLEMENTATION_ID() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) NEXUSACCOUNTIMPLEMENTATIONID(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "NEXUS_ACCOUNT_IMPLEMENTATION_ID")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// NEXUSACCOUNTIMPLEMENTATIONID is a free data retrieval call binding the contract method 0xe8a18c2e.
//
// Solidity: function NEXUS_ACCOUNT_IMPLEMENTATION_ID() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) NEXUSACCOUNTIMPLEMENTATIONID() (string, error) {
	return _AcrossV3AdapterTest.Contract.NEXUSACCOUNTIMPLEMENTATIONID(&_AcrossV3AdapterTest.CallOpts)
}

// NEXUSACCOUNTIMPLEMENTATIONID is a free data retrieval call binding the contract method 0xe8a18c2e.
//
// Solidity: function NEXUS_ACCOUNT_IMPLEMENTATION_ID() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) NEXUSACCOUNTIMPLEMENTATIONID() (string, error) {
	return _AcrossV3AdapterTest.Contract.NEXUSACCOUNTIMPLEMENTATIONID(&_AcrossV3AdapterTest.CallOpts)
}

// ODOSROUTERV3 is a free data retrieval call binding the contract method 0x2b696932.
//
// Solidity: function ODOS_ROUTER_V3() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ODOSROUTERV3(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ODOS_ROUTER_V3")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// ODOSROUTERV3 is a free data retrieval call binding the contract method 0x2b696932.
//
// Solidity: function ODOS_ROUTER_V3() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ODOSROUTERV3() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.ODOSROUTERV3(&_AcrossV3AdapterTest.CallOpts)
}

// ODOSROUTERV3 is a free data retrieval call binding the contract method 0x2b696932.
//
// Solidity: function ODOS_ROUTER_V3() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ODOSROUTERV3() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.ODOSROUTERV3(&_AcrossV3AdapterTest.CallOpts)
}

// OFFRAMPTOKENSHOOKKEY is a free data retrieval call binding the contract method 0x8ba28269.
//
// Solidity: function OFFRAMP_TOKENS_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) OFFRAMPTOKENSHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "OFFRAMP_TOKENS_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// OFFRAMPTOKENSHOOKKEY is a free data retrieval call binding the contract method 0x8ba28269.
//
// Solidity: function OFFRAMP_TOKENS_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) OFFRAMPTOKENSHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.OFFRAMPTOKENSHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// OFFRAMPTOKENSHOOKKEY is a free data retrieval call binding the contract method 0x8ba28269.
//
// Solidity: function OFFRAMP_TOKENS_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) OFFRAMPTOKENSHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.OFFRAMPTOKENSHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ONEINCHAPIKEY is a free data retrieval call binding the contract method 0x375b3e62.
//
// Solidity: function ONE_INCH_API_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ONEINCHAPIKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ONE_INCH_API_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// ONEINCHAPIKEY is a free data retrieval call binding the contract method 0x375b3e62.
//
// Solidity: function ONE_INCH_API_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ONEINCHAPIKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ONEINCHAPIKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ONEINCHAPIKEY is a free data retrieval call binding the contract method 0x375b3e62.
//
// Solidity: function ONE_INCH_API_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ONEINCHAPIKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.ONEINCHAPIKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ONEINCHROUTER is a free data retrieval call binding the contract method 0xdd3fd925.
//
// Solidity: function ONE_INCH_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ONEINCHROUTER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ONE_INCH_ROUTER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// ONEINCHROUTER is a free data retrieval call binding the contract method 0xdd3fd925.
//
// Solidity: function ONE_INCH_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ONEINCHROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.ONEINCHROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// ONEINCHROUTER is a free data retrieval call binding the contract method 0xdd3fd925.
//
// Solidity: function ONE_INCH_ROUTER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ONEINCHROUTER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.ONEINCHROUTER(&_AcrossV3AdapterTest.CallOpts)
}

// OP is a free data retrieval call binding the contract method 0x7c9c3472.
//
// Solidity: function OP() view returns(uint64)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) OP(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "OP")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// OP is a free data retrieval call binding the contract method 0x7c9c3472.
//
// Solidity: function OP() view returns(uint64)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) OP() (uint64, error) {
	return _AcrossV3AdapterTest.Contract.OP(&_AcrossV3AdapterTest.CallOpts)
}

// OP is a free data retrieval call binding the contract method 0x7c9c3472.
//
// Solidity: function OP() view returns(uint64)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) OP() (uint64, error) {
	return _AcrossV3AdapterTest.Contract.OP(&_AcrossV3AdapterTest.CallOpts)
}

// OPTIMISMKEY is a free data retrieval call binding the contract method 0xc61154b7.
//
// Solidity: function OPTIMISM_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) OPTIMISMKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "OPTIMISM_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// OPTIMISMKEY is a free data retrieval call binding the contract method 0xc61154b7.
//
// Solidity: function OPTIMISM_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) OPTIMISMKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.OPTIMISMKEY(&_AcrossV3AdapterTest.CallOpts)
}

// OPTIMISMKEY is a free data retrieval call binding the contract method 0xc61154b7.
//
// Solidity: function OPTIMISM_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) OPTIMISMKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.OPTIMISMKEY(&_AcrossV3AdapterTest.CallOpts)
}

// OPTIMISMRPCURLKEY is a free data retrieval call binding the contract method 0xd0160791.
//
// Solidity: function OPTIMISM_RPC_URL_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) OPTIMISMRPCURLKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "OPTIMISM_RPC_URL_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// OPTIMISMRPCURLKEY is a free data retrieval call binding the contract method 0xd0160791.
//
// Solidity: function OPTIMISM_RPC_URL_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) OPTIMISMRPCURLKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.OPTIMISMRPCURLKEY(&_AcrossV3AdapterTest.CallOpts)
}

// OPTIMISMRPCURLKEY is a free data retrieval call binding the contract method 0xd0160791.
//
// Solidity: function OPTIMISM_RPC_URL_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) OPTIMISMRPCURLKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.OPTIMISMRPCURLKEY(&_AcrossV3AdapterTest.CallOpts)
}

// OPBLOCK is a free data retrieval call binding the contract method 0xc1276b04.
//
// Solidity: function OP_BLOCK() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) OPBLOCK(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "OP_BLOCK")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// OPBLOCK is a free data retrieval call binding the contract method 0xc1276b04.
//
// Solidity: function OP_BLOCK() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) OPBLOCK() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.OPBLOCK(&_AcrossV3AdapterTest.CallOpts)
}

// OPBLOCK is a free data retrieval call binding the contract method 0xc1276b04.
//
// Solidity: function OP_BLOCK() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) OPBLOCK() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.OPBLOCK(&_AcrossV3AdapterTest.CallOpts)
}

// PENDLEETHENAKEY is a free data retrieval call binding the contract method 0xb203dfce.
//
// Solidity: function PENDLE_ETHENA_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) PENDLEETHENAKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "PENDLE_ETHENA_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// PENDLEETHENAKEY is a free data retrieval call binding the contract method 0xb203dfce.
//
// Solidity: function PENDLE_ETHENA_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) PENDLEETHENAKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.PENDLEETHENAKEY(&_AcrossV3AdapterTest.CallOpts)
}

// PENDLEETHENAKEY is a free data retrieval call binding the contract method 0xb203dfce.
//
// Solidity: function PENDLE_ETHENA_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) PENDLEETHENAKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.PENDLEETHENAKEY(&_AcrossV3AdapterTest.CallOpts)
}

// PENDLEROUTERREDEEMHOOKKEY is a free data retrieval call binding the contract method 0x21a99db0.
//
// Solidity: function PENDLE_ROUTER_REDEEM_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) PENDLEROUTERREDEEMHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "PENDLE_ROUTER_REDEEM_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// PENDLEROUTERREDEEMHOOKKEY is a free data retrieval call binding the contract method 0x21a99db0.
//
// Solidity: function PENDLE_ROUTER_REDEEM_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) PENDLEROUTERREDEEMHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.PENDLEROUTERREDEEMHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// PENDLEROUTERREDEEMHOOKKEY is a free data retrieval call binding the contract method 0x21a99db0.
//
// Solidity: function PENDLE_ROUTER_REDEEM_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) PENDLEROUTERREDEEMHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.PENDLEROUTERREDEEMHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// PENDLEROUTERSWAPHOOKKEY is a free data retrieval call binding the contract method 0x2ddd29d1.
//
// Solidity: function PENDLE_ROUTER_SWAP_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) PENDLEROUTERSWAPHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "PENDLE_ROUTER_SWAP_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// PENDLEROUTERSWAPHOOKKEY is a free data retrieval call binding the contract method 0x2ddd29d1.
//
// Solidity: function PENDLE_ROUTER_SWAP_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) PENDLEROUTERSWAPHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.PENDLEROUTERSWAPHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// PENDLEROUTERSWAPHOOKKEY is a free data retrieval call binding the contract method 0x2ddd29d1.
//
// Solidity: function PENDLE_ROUTER_SWAP_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) PENDLEROUTERSWAPHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.PENDLEROUTERSWAPHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// PERMIT2 is a free data retrieval call binding the contract method 0x6afdd850.
//
// Solidity: function PERMIT2() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) PERMIT2(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "PERMIT2")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PERMIT2 is a free data retrieval call binding the contract method 0x6afdd850.
//
// Solidity: function PERMIT2() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) PERMIT2() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.PERMIT2(&_AcrossV3AdapterTest.CallOpts)
}

// PERMIT2 is a free data retrieval call binding the contract method 0x6afdd850.
//
// Solidity: function PERMIT2() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) PERMIT2() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.PERMIT2(&_AcrossV3AdapterTest.CallOpts)
}

// PERMITWITHPERMIT2HOOKKEY is a free data retrieval call binding the contract method 0x13fd203c.
//
// Solidity: function PERMIT_WITH_PERMIT2_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) PERMITWITHPERMIT2HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "PERMIT_WITH_PERMIT2_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// PERMITWITHPERMIT2HOOKKEY is a free data retrieval call binding the contract method 0x13fd203c.
//
// Solidity: function PERMIT_WITH_PERMIT2_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) PERMITWITHPERMIT2HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.PERMITWITHPERMIT2HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// PERMITWITHPERMIT2HOOKKEY is a free data retrieval call binding the contract method 0x13fd203c.
//
// Solidity: function PERMIT_WITH_PERMIT2_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) PERMITWITHPERMIT2HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.PERMITWITHPERMIT2HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// REDEEM4626VAULTHOOKKEY is a free data retrieval call binding the contract method 0x6f6d75bb.
//
// Solidity: function REDEEM_4626_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) REDEEM4626VAULTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "REDEEM_4626_VAULT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// REDEEM4626VAULTHOOKKEY is a free data retrieval call binding the contract method 0x6f6d75bb.
//
// Solidity: function REDEEM_4626_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) REDEEM4626VAULTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.REDEEM4626VAULTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// REDEEM4626VAULTHOOKKEY is a free data retrieval call binding the contract method 0x6f6d75bb.
//
// Solidity: function REDEEM_4626_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) REDEEM4626VAULTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.REDEEM4626VAULTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// REDEEM5115VAULTHOOKKEY is a free data retrieval call binding the contract method 0xdf4dcf31.
//
// Solidity: function REDEEM_5115_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) REDEEM5115VAULTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "REDEEM_5115_VAULT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// REDEEM5115VAULTHOOKKEY is a free data retrieval call binding the contract method 0xdf4dcf31.
//
// Solidity: function REDEEM_5115_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) REDEEM5115VAULTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.REDEEM5115VAULTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// REDEEM5115VAULTHOOKKEY is a free data retrieval call binding the contract method 0xdf4dcf31.
//
// Solidity: function REDEEM_5115_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) REDEEM5115VAULTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.REDEEM5115VAULTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// REDEEM7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x8b5cc9f1.
//
// Solidity: function REDEEM_7540_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) REDEEM7540VAULTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "REDEEM_7540_VAULT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// REDEEM7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x8b5cc9f1.
//
// Solidity: function REDEEM_7540_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) REDEEM7540VAULTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.REDEEM7540VAULTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// REDEEM7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x8b5cc9f1.
//
// Solidity: function REDEEM_7540_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) REDEEM7540VAULTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.REDEEM7540VAULTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// REQUESTDEPOSIT7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x67503ae4.
//
// Solidity: function REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) REQUESTDEPOSIT7540VAULTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// REQUESTDEPOSIT7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x67503ae4.
//
// Solidity: function REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) REQUESTDEPOSIT7540VAULTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.REQUESTDEPOSIT7540VAULTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// REQUESTDEPOSIT7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x67503ae4.
//
// Solidity: function REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) REQUESTDEPOSIT7540VAULTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.REQUESTDEPOSIT7540VAULTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// REQUESTREDEEM7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0xa1f9762e.
//
// Solidity: function REQUEST_REDEEM_7540_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) REQUESTREDEEM7540VAULTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "REQUEST_REDEEM_7540_VAULT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// REQUESTREDEEM7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0xa1f9762e.
//
// Solidity: function REQUEST_REDEEM_7540_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) REQUESTREDEEM7540VAULTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.REQUESTREDEEM7540VAULTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// REQUESTREDEEM7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0xa1f9762e.
//
// Solidity: function REQUEST_REDEEM_7540_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) REQUESTREDEEM7540VAULTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.REQUESTREDEEM7540VAULTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// ROLESID is a free data retrieval call binding the contract method 0x6312d5d0.
//
// Solidity: function ROLES_ID() view returns(bytes32)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ROLESID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "ROLES_ID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ROLESID is a free data retrieval call binding the contract method 0x6312d5d0.
//
// Solidity: function ROLES_ID() view returns(bytes32)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ROLESID() ([32]byte, error) {
	return _AcrossV3AdapterTest.Contract.ROLESID(&_AcrossV3AdapterTest.CallOpts)
}

// ROLESID is a free data retrieval call binding the contract method 0x6312d5d0.
//
// Solidity: function ROLES_ID() view returns(bytes32)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ROLESID() ([32]byte, error) {
	return _AcrossV3AdapterTest.Contract.ROLESID(&_AcrossV3AdapterTest.CallOpts)
}

// SAFEREGISTRYADDR is a free data retrieval call binding the contract method 0x7d452df6.
//
// Solidity: function SAFE_REGISTRY_ADDR() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SAFEREGISTRYADDR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SAFE_REGISTRY_ADDR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SAFEREGISTRYADDR is a free data retrieval call binding the contract method 0x7d452df6.
//
// Solidity: function SAFE_REGISTRY_ADDR() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SAFEREGISTRYADDR() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.SAFEREGISTRYADDR(&_AcrossV3AdapterTest.CallOpts)
}

// SAFEREGISTRYADDR is a free data retrieval call binding the contract method 0x7d452df6.
//
// Solidity: function SAFE_REGISTRY_ADDR() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SAFEREGISTRYADDR() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.SAFEREGISTRYADDR(&_AcrossV3AdapterTest.CallOpts)
}

// SMALL is a free data retrieval call binding the contract method 0xe8b7c8ad.
//
// Solidity: function SMALL() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SMALL(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SMALL")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// SMALL is a free data retrieval call binding the contract method 0xe8b7c8ad.
//
// Solidity: function SMALL() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SMALL() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.SMALL(&_AcrossV3AdapterTest.CallOpts)
}

// SMALL is a free data retrieval call binding the contract method 0xe8b7c8ad.
//
// Solidity: function SMALL() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SMALL() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.SMALL(&_AcrossV3AdapterTest.CallOpts)
}

// SOMELIERSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xc30c1920.
//
// Solidity: function SOMELIER_STAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SOMELIERSTAKEHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SOMELIER_STAKE_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SOMELIERSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xc30c1920.
//
// Solidity: function SOMELIER_STAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SOMELIERSTAKEHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SOMELIERSTAKEHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SOMELIERSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xc30c1920.
//
// Solidity: function SOMELIER_STAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SOMELIERSTAKEHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SOMELIERSTAKEHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SOMELIERUNBONDALLHOOKKEY is a free data retrieval call binding the contract method 0x27348f31.
//
// Solidity: function SOMELIER_UNBOND_ALL_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SOMELIERUNBONDALLHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SOMELIER_UNBOND_ALL_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SOMELIERUNBONDALLHOOKKEY is a free data retrieval call binding the contract method 0x27348f31.
//
// Solidity: function SOMELIER_UNBOND_ALL_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SOMELIERUNBONDALLHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SOMELIERUNBONDALLHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SOMELIERUNBONDALLHOOKKEY is a free data retrieval call binding the contract method 0x27348f31.
//
// Solidity: function SOMELIER_UNBOND_ALL_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SOMELIERUNBONDALLHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SOMELIERUNBONDALLHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SOMELIERUNBONDHOOKKEY is a free data retrieval call binding the contract method 0xb92b4b98.
//
// Solidity: function SOMELIER_UNBOND_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SOMELIERUNBONDHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SOMELIER_UNBOND_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SOMELIERUNBONDHOOKKEY is a free data retrieval call binding the contract method 0xb92b4b98.
//
// Solidity: function SOMELIER_UNBOND_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SOMELIERUNBONDHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SOMELIERUNBONDHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SOMELIERUNBONDHOOKKEY is a free data retrieval call binding the contract method 0xb92b4b98.
//
// Solidity: function SOMELIER_UNBOND_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SOMELIERUNBONDHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SOMELIERUNBONDHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SOMELIERUNSTAKEALLHOOKKEY is a free data retrieval call binding the contract method 0x9aa397e9.
//
// Solidity: function SOMELIER_UNSTAKE_ALL_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SOMELIERUNSTAKEALLHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SOMELIER_UNSTAKE_ALL_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SOMELIERUNSTAKEALLHOOKKEY is a free data retrieval call binding the contract method 0x9aa397e9.
//
// Solidity: function SOMELIER_UNSTAKE_ALL_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SOMELIERUNSTAKEALLHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SOMELIERUNSTAKEALLHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SOMELIERUNSTAKEALLHOOKKEY is a free data retrieval call binding the contract method 0x9aa397e9.
//
// Solidity: function SOMELIER_UNSTAKE_ALL_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SOMELIERUNSTAKEALLHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SOMELIERUNSTAKEALLHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SOMELIERUNSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xa6186e9a.
//
// Solidity: function SOMELIER_UNSTAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SOMELIERUNSTAKEHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SOMELIER_UNSTAKE_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SOMELIERUNSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xa6186e9a.
//
// Solidity: function SOMELIER_UNSTAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SOMELIERUNSTAKEHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SOMELIERUNSTAKEHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SOMELIERUNSTAKEHOOKKEY is a free data retrieval call binding the contract method 0xa6186e9a.
//
// Solidity: function SOMELIER_UNSTAKE_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SOMELIERUNSTAKEHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SOMELIERUNSTAKEHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SPARKUSDCVAULTKEY is a free data retrieval call binding the contract method 0x9c86a52c.
//
// Solidity: function SPARK_USDC_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SPARKUSDCVAULTKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SPARK_USDC_VAULT_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SPARKUSDCVAULTKEY is a free data retrieval call binding the contract method 0x9c86a52c.
//
// Solidity: function SPARK_USDC_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SPARKUSDCVAULTKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SPARKUSDCVAULTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SPARKUSDCVAULTKEY is a free data retrieval call binding the contract method 0x9c86a52c.
//
// Solidity: function SPARK_USDC_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SPARKUSDCVAULTKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SPARKUSDCVAULTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SPECTRAEXCHANGEDEPOSITHOOKKEY is a free data retrieval call binding the contract method 0x5a45abc1.
//
// Solidity: function SPECTRA_EXCHANGE_DEPOSIT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SPECTRAEXCHANGEDEPOSITHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SPECTRA_EXCHANGE_DEPOSIT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SPECTRAEXCHANGEDEPOSITHOOKKEY is a free data retrieval call binding the contract method 0x5a45abc1.
//
// Solidity: function SPECTRA_EXCHANGE_DEPOSIT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SPECTRAEXCHANGEDEPOSITHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SPECTRAEXCHANGEDEPOSITHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SPECTRAEXCHANGEDEPOSITHOOKKEY is a free data retrieval call binding the contract method 0x5a45abc1.
//
// Solidity: function SPECTRA_EXCHANGE_DEPOSIT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SPECTRAEXCHANGEDEPOSITHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SPECTRAEXCHANGEDEPOSITHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SPECTRAEXCHANGEREDEEMHOOKKEY is a free data retrieval call binding the contract method 0x8732a9d1.
//
// Solidity: function SPECTRA_EXCHANGE_REDEEM_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SPECTRAEXCHANGEREDEEMHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SPECTRA_EXCHANGE_REDEEM_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SPECTRAEXCHANGEREDEEMHOOKKEY is a free data retrieval call binding the contract method 0x8732a9d1.
//
// Solidity: function SPECTRA_EXCHANGE_REDEEM_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SPECTRAEXCHANGEREDEEMHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SPECTRAEXCHANGEREDEEMHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SPECTRAEXCHANGEREDEEMHOOKKEY is a free data retrieval call binding the contract method 0x8732a9d1.
//
// Solidity: function SPECTRA_EXCHANGE_REDEEM_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SPECTRAEXCHANGEREDEEMHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SPECTRAEXCHANGEREDEEMHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// STAKINGYIELDSOURCEORACLEKEY is a free data retrieval call binding the contract method 0xdbf8e232.
//
// Solidity: function STAKING_YIELD_SOURCE_ORACLE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) STAKINGYIELDSOURCEORACLEKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "STAKING_YIELD_SOURCE_ORACLE_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// STAKINGYIELDSOURCEORACLEKEY is a free data retrieval call binding the contract method 0xdbf8e232.
//
// Solidity: function STAKING_YIELD_SOURCE_ORACLE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) STAKINGYIELDSOURCEORACLEKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.STAKINGYIELDSOURCEORACLEKEY(&_AcrossV3AdapterTest.CallOpts)
}

// STAKINGYIELDSOURCEORACLEKEY is a free data retrieval call binding the contract method 0xdbf8e232.
//
// Solidity: function STAKING_YIELD_SOURCE_ORACLE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) STAKINGYIELDSOURCEORACLEKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.STAKINGYIELDSOURCEORACLEKEY(&_AcrossV3AdapterTest.CallOpts)
}

// STRATEGISTKEY is a free data retrieval call binding the contract method 0x7a67e8c1.
//
// Solidity: function STRATEGIST_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) STRATEGISTKEY(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "STRATEGIST_KEY")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// STRATEGISTKEY is a free data retrieval call binding the contract method 0x7a67e8c1.
//
// Solidity: function STRATEGIST_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) STRATEGISTKEY() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.STRATEGISTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// STRATEGISTKEY is a free data retrieval call binding the contract method 0x7a67e8c1.
//
// Solidity: function STRATEGIST_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) STRATEGISTKEY() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.STRATEGISTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SUPER7702SENDERCREATORKEY is a free data retrieval call binding the contract method 0xf5c1ccf6.
//
// Solidity: function SUPER_7702_SENDER_CREATOR_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SUPER7702SENDERCREATORKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SUPER_7702_SENDER_CREATOR_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SUPER7702SENDERCREATORKEY is a free data retrieval call binding the contract method 0xf5c1ccf6.
//
// Solidity: function SUPER_7702_SENDER_CREATOR_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SUPER7702SENDERCREATORKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SUPER7702SENDERCREATORKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SUPER7702SENDERCREATORKEY is a free data retrieval call binding the contract method 0xf5c1ccf6.
//
// Solidity: function SUPER_7702_SENDER_CREATOR_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SUPER7702SENDERCREATORKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SUPER7702SENDERCREATORKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SUPERBUNDLER is a free data retrieval call binding the contract method 0x4ddbd878.
//
// Solidity: function SUPER_BUNDLER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SUPERBUNDLER(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SUPER_BUNDLER")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERBUNDLER is a free data retrieval call binding the contract method 0x4ddbd878.
//
// Solidity: function SUPER_BUNDLER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SUPERBUNDLER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.SUPERBUNDLER(&_AcrossV3AdapterTest.CallOpts)
}

// SUPERBUNDLER is a free data retrieval call binding the contract method 0x4ddbd878.
//
// Solidity: function SUPER_BUNDLER() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SUPERBUNDLER() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.SUPERBUNDLER(&_AcrossV3AdapterTest.CallOpts)
}

// SUPERBUNDLERKEY is a free data retrieval call binding the contract method 0x5e2592df.
//
// Solidity: function SUPER_BUNDLER_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SUPERBUNDLERKEY(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SUPER_BUNDLER_KEY")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// SUPERBUNDLERKEY is a free data retrieval call binding the contract method 0x5e2592df.
//
// Solidity: function SUPER_BUNDLER_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SUPERBUNDLERKEY() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.SUPERBUNDLERKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SUPERBUNDLERKEY is a free data retrieval call binding the contract method 0x5e2592df.
//
// Solidity: function SUPER_BUNDLER_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SUPERBUNDLERKEY() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.SUPERBUNDLERKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SUPERCOLLECTIVEVAULTKEY is a free data retrieval call binding the contract method 0xb1e80bfc.
//
// Solidity: function SUPER_COLLECTIVE_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SUPERCOLLECTIVEVAULTKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SUPER_COLLECTIVE_VAULT_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SUPERCOLLECTIVEVAULTKEY is a free data retrieval call binding the contract method 0xb1e80bfc.
//
// Solidity: function SUPER_COLLECTIVE_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SUPERCOLLECTIVEVAULTKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SUPERCOLLECTIVEVAULTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SUPERCOLLECTIVEVAULTKEY is a free data retrieval call binding the contract method 0xb1e80bfc.
//
// Solidity: function SUPER_COLLECTIVE_VAULT_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SUPERCOLLECTIVEVAULTKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SUPERCOLLECTIVEVAULTKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SUPERDESTINATIONEXECUTORKEY is a free data retrieval call binding the contract method 0xf44c853a.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SUPERDESTINATIONEXECUTORKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SUPER_DESTINATION_EXECUTOR_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SUPERDESTINATIONEXECUTORKEY is a free data retrieval call binding the contract method 0xf44c853a.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SUPERDESTINATIONEXECUTORKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SUPERDESTINATIONEXECUTORKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SUPERDESTINATIONEXECUTORKEY is a free data retrieval call binding the contract method 0xf44c853a.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SUPERDESTINATIONEXECUTORKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SUPERDESTINATIONEXECUTORKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SUPERDESTINATIONVALIDATORKEY is a free data retrieval call binding the contract method 0x8f66c5f1.
//
// Solidity: function SUPER_DESTINATION_VALIDATOR_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SUPERDESTINATIONVALIDATORKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SUPER_DESTINATION_VALIDATOR_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SUPERDESTINATIONVALIDATORKEY is a free data retrieval call binding the contract method 0x8f66c5f1.
//
// Solidity: function SUPER_DESTINATION_VALIDATOR_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SUPERDESTINATIONVALIDATORKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SUPERDESTINATIONVALIDATORKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SUPERDESTINATIONVALIDATORKEY is a free data retrieval call binding the contract method 0x8f66c5f1.
//
// Solidity: function SUPER_DESTINATION_VALIDATOR_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SUPERDESTINATIONVALIDATORKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SUPERDESTINATIONVALIDATORKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SUPEREXECUTORKEY is a free data retrieval call binding the contract method 0x6b6df5da.
//
// Solidity: function SUPER_EXECUTOR_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SUPEREXECUTORKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SUPER_EXECUTOR_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SUPEREXECUTORKEY is a free data retrieval call binding the contract method 0x6b6df5da.
//
// Solidity: function SUPER_EXECUTOR_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SUPEREXECUTORKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SUPEREXECUTORKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SUPEREXECUTORKEY is a free data retrieval call binding the contract method 0x6b6df5da.
//
// Solidity: function SUPER_EXECUTOR_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SUPEREXECUTORKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SUPEREXECUTORKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SUPERGASTANKID is a free data retrieval call binding the contract method 0x32740077.
//
// Solidity: function SUPER_GAS_TANK_ID() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SUPERGASTANKID(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SUPER_GAS_TANK_ID")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SUPERGASTANKID is a free data retrieval call binding the contract method 0x32740077.
//
// Solidity: function SUPER_GAS_TANK_ID() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SUPERGASTANKID() (string, error) {
	return _AcrossV3AdapterTest.Contract.SUPERGASTANKID(&_AcrossV3AdapterTest.CallOpts)
}

// SUPERGASTANKID is a free data retrieval call binding the contract method 0x32740077.
//
// Solidity: function SUPER_GAS_TANK_ID() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SUPERGASTANKID() (string, error) {
	return _AcrossV3AdapterTest.Contract.SUPERGASTANKID(&_AcrossV3AdapterTest.CallOpts)
}

// SUPERLEDGERCONFIGURATIONKEY is a free data retrieval call binding the contract method 0x22ab9837.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SUPERLEDGERCONFIGURATIONKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SUPER_LEDGER_CONFIGURATION_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SUPERLEDGERCONFIGURATIONKEY is a free data retrieval call binding the contract method 0x22ab9837.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SUPERLEDGERCONFIGURATIONKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SUPERLEDGERCONFIGURATIONKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SUPERLEDGERCONFIGURATIONKEY is a free data retrieval call binding the contract method 0x22ab9837.
//
// Solidity: function SUPER_LEDGER_CONFIGURATION_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SUPERLEDGERCONFIGURATIONKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SUPERLEDGERCONFIGURATIONKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SUPERLEDGERKEY is a free data retrieval call binding the contract method 0xb997902d.
//
// Solidity: function SUPER_LEDGER_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SUPERLEDGERKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SUPER_LEDGER_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SUPERLEDGERKEY is a free data retrieval call binding the contract method 0xb997902d.
//
// Solidity: function SUPER_LEDGER_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SUPERLEDGERKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SUPERLEDGERKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SUPERLEDGERKEY is a free data retrieval call binding the contract method 0xb997902d.
//
// Solidity: function SUPER_LEDGER_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SUPERLEDGERKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SUPERLEDGERKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SUPERMERKLEVALIDATORKEY is a free data retrieval call binding the contract method 0x77aa7a91.
//
// Solidity: function SUPER_MERKLE_VALIDATOR_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SUPERMERKLEVALIDATORKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SUPER_MERKLE_VALIDATOR_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SUPERMERKLEVALIDATORKEY is a free data retrieval call binding the contract method 0x77aa7a91.
//
// Solidity: function SUPER_MERKLE_VALIDATOR_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SUPERMERKLEVALIDATORKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SUPERMERKLEVALIDATORKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SUPERMERKLEVALIDATORKEY is a free data retrieval call binding the contract method 0x77aa7a91.
//
// Solidity: function SUPER_MERKLE_VALIDATOR_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SUPERMERKLEVALIDATORKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SUPERMERKLEVALIDATORKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SUPERNATIVEPAYMASTERKEY is a free data retrieval call binding the contract method 0x44328cd5.
//
// Solidity: function SUPER_NATIVE_PAYMASTER_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SUPERNATIVEPAYMASTERKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SUPER_NATIVE_PAYMASTER_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SUPERNATIVEPAYMASTERKEY is a free data retrieval call binding the contract method 0x44328cd5.
//
// Solidity: function SUPER_NATIVE_PAYMASTER_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SUPERNATIVEPAYMASTERKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SUPERNATIVEPAYMASTERKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SUPERNATIVEPAYMASTERKEY is a free data retrieval call binding the contract method 0x44328cd5.
//
// Solidity: function SUPER_NATIVE_PAYMASTER_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SUPERNATIVEPAYMASTERKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SUPERNATIVEPAYMASTERKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SUPERSENDERCREATORKEY is a free data retrieval call binding the contract method 0x55cb93ba.
//
// Solidity: function SUPER_SENDER_CREATOR_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SUPERSENDERCREATORKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SUPER_SENDER_CREATOR_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SUPERSENDERCREATORKEY is a free data retrieval call binding the contract method 0x55cb93ba.
//
// Solidity: function SUPER_SENDER_CREATOR_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SUPERSENDERCREATORKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SUPERSENDERCREATORKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SUPERSENDERCREATORKEY is a free data retrieval call binding the contract method 0x55cb93ba.
//
// Solidity: function SUPER_SENDER_CREATOR_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SUPERSENDERCREATORKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SUPERSENDERCREATORKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SUSDEKEY is a free data retrieval call binding the contract method 0x8cf396ee.
//
// Solidity: function SUSDE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SUSDEKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SUSDE_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SUSDEKEY is a free data retrieval call binding the contract method 0x8cf396ee.
//
// Solidity: function SUSDE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SUSDEKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SUSDEKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SUSDEKEY is a free data retrieval call binding the contract method 0x8cf396ee.
//
// Solidity: function SUSDE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SUSDEKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SUSDEKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SWAP1INCHHOOKKEY is a free data retrieval call binding the contract method 0xddf2a077.
//
// Solidity: function SWAP_1INCH_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SWAP1INCHHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SWAP_1INCH_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SWAP1INCHHOOKKEY is a free data retrieval call binding the contract method 0xddf2a077.
//
// Solidity: function SWAP_1INCH_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SWAP1INCHHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SWAP1INCHHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SWAP1INCHHOOKKEY is a free data retrieval call binding the contract method 0xddf2a077.
//
// Solidity: function SWAP_1INCH_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SWAP1INCHHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SWAP1INCHHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SWAPALGEBRAINTEGRALHOOKKEY is a free data retrieval call binding the contract method 0x262ba544.
//
// Solidity: function SWAP_ALGEBRA_INTEGRAL_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SWAPALGEBRAINTEGRALHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SWAP_ALGEBRA_INTEGRAL_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SWAPALGEBRAINTEGRALHOOKKEY is a free data retrieval call binding the contract method 0x262ba544.
//
// Solidity: function SWAP_ALGEBRA_INTEGRAL_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SWAPALGEBRAINTEGRALHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SWAPALGEBRAINTEGRALHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SWAPALGEBRAINTEGRALHOOKKEY is a free data retrieval call binding the contract method 0x262ba544.
//
// Solidity: function SWAP_ALGEBRA_INTEGRAL_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SWAPALGEBRAINTEGRALHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SWAPALGEBRAINTEGRALHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SWAPODOSV2HOOKKEY is a free data retrieval call binding the contract method 0x2625b00e.
//
// Solidity: function SWAP_ODOSV2_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SWAPODOSV2HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SWAP_ODOSV2_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SWAPODOSV2HOOKKEY is a free data retrieval call binding the contract method 0x2625b00e.
//
// Solidity: function SWAP_ODOSV2_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SWAPODOSV2HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SWAPODOSV2HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SWAPODOSV2HOOKKEY is a free data retrieval call binding the contract method 0x2625b00e.
//
// Solidity: function SWAP_ODOSV2_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SWAPODOSV2HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SWAPODOSV2HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SWAPOPENOCEANSPARKDEXHOOKKEY is a free data retrieval call binding the contract method 0x78a941d3.
//
// Solidity: function SWAP_OPENOCEAN_SPARKDEX_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SWAPOPENOCEANSPARKDEXHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SWAP_OPENOCEAN_SPARKDEX_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SWAPOPENOCEANSPARKDEXHOOKKEY is a free data retrieval call binding the contract method 0x78a941d3.
//
// Solidity: function SWAP_OPENOCEAN_SPARKDEX_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SWAPOPENOCEANSPARKDEXHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SWAPOPENOCEANSPARKDEXHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SWAPOPENOCEANSPARKDEXHOOKKEY is a free data retrieval call binding the contract method 0x78a941d3.
//
// Solidity: function SWAP_OPENOCEAN_SPARKDEX_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SWAPOPENOCEANSPARKDEXHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SWAPOPENOCEANSPARKDEXHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SWAPUNISWAPV3HOOKKEY is a free data retrieval call binding the contract method 0x5278fef8.
//
// Solidity: function SWAP_UNISWAP_V3_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SWAPUNISWAPV3HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SWAP_UNISWAP_V3_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SWAPUNISWAPV3HOOKKEY is a free data retrieval call binding the contract method 0x5278fef8.
//
// Solidity: function SWAP_UNISWAP_V3_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SWAPUNISWAPV3HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SWAPUNISWAPV3HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SWAPUNISWAPV3HOOKKEY is a free data retrieval call binding the contract method 0x5278fef8.
//
// Solidity: function SWAP_UNISWAP_V3_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SWAPUNISWAPV3HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SWAPUNISWAPV3HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SWAPUNISWAPV4HOOKKEY is a free data retrieval call binding the contract method 0xda562b89.
//
// Solidity: function SWAP_UNISWAP_V4_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SWAPUNISWAPV4HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SWAP_UNISWAP_V4_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SWAPUNISWAPV4HOOKKEY is a free data retrieval call binding the contract method 0xda562b89.
//
// Solidity: function SWAP_UNISWAP_V4_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SWAPUNISWAPV4HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SWAPUNISWAPV4HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SWAPUNISWAPV4HOOKKEY is a free data retrieval call binding the contract method 0xda562b89.
//
// Solidity: function SWAP_UNISWAP_V4_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SWAPUNISWAPV4HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SWAPUNISWAPV4HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SWAPUNISWAPV4MULTIHOPHOOKKEY is a free data retrieval call binding the contract method 0x4059361b.
//
// Solidity: function SWAP_UNISWAP_V4_MULTI_HOP_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) SWAPUNISWAPV4MULTIHOPHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "SWAP_UNISWAP_V4_MULTI_HOP_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// SWAPUNISWAPV4MULTIHOPHOOKKEY is a free data retrieval call binding the contract method 0x4059361b.
//
// Solidity: function SWAP_UNISWAP_V4_MULTI_HOP_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SWAPUNISWAPV4MULTIHOPHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SWAPUNISWAPV4MULTIHOPHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// SWAPUNISWAPV4MULTIHOPHOOKKEY is a free data retrieval call binding the contract method 0x4059361b.
//
// Solidity: function SWAP_UNISWAP_V4_MULTI_HOP_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) SWAPUNISWAPV4MULTIHOPHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.SWAPUNISWAPV4MULTIHOPHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// TRANSFERERC20HOOKKEY is a free data retrieval call binding the contract method 0x1800af24.
//
// Solidity: function TRANSFER_ERC20_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) TRANSFERERC20HOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "TRANSFER_ERC20_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// TRANSFERERC20HOOKKEY is a free data retrieval call binding the contract method 0x1800af24.
//
// Solidity: function TRANSFER_ERC20_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) TRANSFERERC20HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.TRANSFERERC20HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// TRANSFERERC20HOOKKEY is a free data retrieval call binding the contract method 0x1800af24.
//
// Solidity: function TRANSFER_ERC20_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) TRANSFERERC20HOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.TRANSFERERC20HOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// TREASURY is a free data retrieval call binding the contract method 0x2d2c5565.
//
// Solidity: function TREASURY() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) TREASURY(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "TREASURY")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// TREASURY is a free data retrieval call binding the contract method 0x2d2c5565.
//
// Solidity: function TREASURY() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) TREASURY() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.TREASURY(&_AcrossV3AdapterTest.CallOpts)
}

// TREASURY is a free data retrieval call binding the contract method 0x2d2c5565.
//
// Solidity: function TREASURY() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) TREASURY() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.TREASURY(&_AcrossV3AdapterTest.CallOpts)
}

// TREASURYKEY is a free data retrieval call binding the contract method 0xfa3c6254.
//
// Solidity: function TREASURY_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) TREASURYKEY(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "TREASURY_KEY")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// TREASURYKEY is a free data retrieval call binding the contract method 0xfa3c6254.
//
// Solidity: function TREASURY_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) TREASURYKEY() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.TREASURYKEY(&_AcrossV3AdapterTest.CallOpts)
}

// TREASURYKEY is a free data retrieval call binding the contract method 0xfa3c6254.
//
// Solidity: function TREASURY_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) TREASURYKEY() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.TREASURYKEY(&_AcrossV3AdapterTest.CallOpts)
}

// USDCEKEY is a free data retrieval call binding the contract method 0x5ff2fe61.
//
// Solidity: function USDCE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) USDCEKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "USDCE_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// USDCEKEY is a free data retrieval call binding the contract method 0x5ff2fe61.
//
// Solidity: function USDCE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) USDCEKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.USDCEKEY(&_AcrossV3AdapterTest.CallOpts)
}

// USDCEKEY is a free data retrieval call binding the contract method 0x5ff2fe61.
//
// Solidity: function USDCE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) USDCEKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.USDCEKEY(&_AcrossV3AdapterTest.CallOpts)
}

// USDCKEY is a free data retrieval call binding the contract method 0x805485b8.
//
// Solidity: function USDC_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) USDCKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "USDC_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// USDCKEY is a free data retrieval call binding the contract method 0x805485b8.
//
// Solidity: function USDC_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) USDCKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.USDCKEY(&_AcrossV3AdapterTest.CallOpts)
}

// USDCKEY is a free data retrieval call binding the contract method 0x805485b8.
//
// Solidity: function USDC_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) USDCKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.USDCKEY(&_AcrossV3AdapterTest.CallOpts)
}

// USDEKEY is a free data retrieval call binding the contract method 0x49201c20.
//
// Solidity: function USDE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) USDEKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "USDE_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// USDEKEY is a free data retrieval call binding the contract method 0x49201c20.
//
// Solidity: function USDE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) USDEKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.USDEKEY(&_AcrossV3AdapterTest.CallOpts)
}

// USDEKEY is a free data retrieval call binding the contract method 0x49201c20.
//
// Solidity: function USDE_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) USDEKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.USDEKEY(&_AcrossV3AdapterTest.CallOpts)
}

// USER1KEY is a free data retrieval call binding the contract method 0xe9d2f1e3.
//
// Solidity: function USER1_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) USER1KEY(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "USER1_KEY")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// USER1KEY is a free data retrieval call binding the contract method 0xe9d2f1e3.
//
// Solidity: function USER1_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) USER1KEY() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.USER1KEY(&_AcrossV3AdapterTest.CallOpts)
}

// USER1KEY is a free data retrieval call binding the contract method 0xe9d2f1e3.
//
// Solidity: function USER1_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) USER1KEY() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.USER1KEY(&_AcrossV3AdapterTest.CallOpts)
}

// USER2KEY is a free data retrieval call binding the contract method 0x60ae3e2e.
//
// Solidity: function USER2_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) USER2KEY(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "USER2_KEY")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// USER2KEY is a free data retrieval call binding the contract method 0x60ae3e2e.
//
// Solidity: function USER2_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) USER2KEY() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.USER2KEY(&_AcrossV3AdapterTest.CallOpts)
}

// USER2KEY is a free data retrieval call binding the contract method 0x60ae3e2e.
//
// Solidity: function USER2_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) USER2KEY() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.USER2KEY(&_AcrossV3AdapterTest.CallOpts)
}

// VALIDATORKEY is a free data retrieval call binding the contract method 0x91be41d5.
//
// Solidity: function VALIDATOR_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) VALIDATORKEY(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "VALIDATOR_KEY")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// VALIDATORKEY is a free data retrieval call binding the contract method 0x91be41d5.
//
// Solidity: function VALIDATOR_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) VALIDATORKEY() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.VALIDATORKEY(&_AcrossV3AdapterTest.CallOpts)
}

// VALIDATORKEY is a free data retrieval call binding the contract method 0x91be41d5.
//
// Solidity: function VALIDATOR_KEY() view returns(uint256)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) VALIDATORKEY() (*big.Int, error) {
	return _AcrossV3AdapterTest.Contract.VALIDATORKEY(&_AcrossV3AdapterTest.CallOpts)
}

// WETHKEY is a free data retrieval call binding the contract method 0x513941b9.
//
// Solidity: function WETH_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) WETHKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "WETH_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// WETHKEY is a free data retrieval call binding the contract method 0x513941b9.
//
// Solidity: function WETH_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) WETHKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.WETHKEY(&_AcrossV3AdapterTest.CallOpts)
}

// WETHKEY is a free data retrieval call binding the contract method 0x513941b9.
//
// Solidity: function WETH_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) WETHKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.WETHKEY(&_AcrossV3AdapterTest.CallOpts)
}

// WITHDRAW7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x467019e9.
//
// Solidity: function WITHDRAW_7540_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) WITHDRAW7540VAULTHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "WITHDRAW_7540_VAULT_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// WITHDRAW7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x467019e9.
//
// Solidity: function WITHDRAW_7540_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) WITHDRAW7540VAULTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.WITHDRAW7540VAULTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// WITHDRAW7540VAULTHOOKKEY is a free data retrieval call binding the contract method 0x467019e9.
//
// Solidity: function WITHDRAW_7540_VAULT_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) WITHDRAW7540VAULTHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.WITHDRAW7540VAULTHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// WSTETHKEY is a free data retrieval call binding the contract method 0x14d8edbe.
//
// Solidity: function WST_ETH_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) WSTETHKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "WST_ETH_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// WSTETHKEY is a free data retrieval call binding the contract method 0x14d8edbe.
//
// Solidity: function WST_ETH_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) WSTETHKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.WSTETHKEY(&_AcrossV3AdapterTest.CallOpts)
}

// WSTETHKEY is a free data retrieval call binding the contract method 0x14d8edbe.
//
// Solidity: function WST_ETH_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) WSTETHKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.WSTETHKEY(&_AcrossV3AdapterTest.CallOpts)
}

// YEARNCLAIMALLREWARDSHOOKKEY is a free data retrieval call binding the contract method 0xec850ab2.
//
// Solidity: function YEARN_CLAIM_ALL_REWARDS_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) YEARNCLAIMALLREWARDSHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "YEARN_CLAIM_ALL_REWARDS_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// YEARNCLAIMALLREWARDSHOOKKEY is a free data retrieval call binding the contract method 0xec850ab2.
//
// Solidity: function YEARN_CLAIM_ALL_REWARDS_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) YEARNCLAIMALLREWARDSHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.YEARNCLAIMALLREWARDSHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// YEARNCLAIMALLREWARDSHOOKKEY is a free data retrieval call binding the contract method 0xec850ab2.
//
// Solidity: function YEARN_CLAIM_ALL_REWARDS_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) YEARNCLAIMALLREWARDSHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.YEARNCLAIMALLREWARDSHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// YEARNCLAIMONEREWARDHOOKKEY is a free data retrieval call binding the contract method 0x0e672aa1.
//
// Solidity: function YEARN_CLAIM_ONE_REWARD_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) YEARNCLAIMONEREWARDHOOKKEY(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "YEARN_CLAIM_ONE_REWARD_HOOK_KEY")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// YEARNCLAIMONEREWARDHOOKKEY is a free data retrieval call binding the contract method 0x0e672aa1.
//
// Solidity: function YEARN_CLAIM_ONE_REWARD_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) YEARNCLAIMONEREWARDHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.YEARNCLAIMONEREWARDHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// YEARNCLAIMONEREWARDHOOKKEY is a free data retrieval call binding the contract method 0x0e672aa1.
//
// Solidity: function YEARN_CLAIM_ONE_REWARD_HOOK_KEY() view returns(string)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) YEARNCLAIMONEREWARDHOOKKEY() (string, error) {
	return _AcrossV3AdapterTest.Contract.YEARNCLAIMONEREWARDHOOKKEY(&_AcrossV3AdapterTest.CallOpts)
}

// AcrossV3Adapter is a free data retrieval call binding the contract method 0x3391c954.
//
// Solidity: function acrossV3Adapter() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) AcrossV3Adapter(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "acrossV3Adapter")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AcrossV3Adapter is a free data retrieval call binding the contract method 0x3391c954.
//
// Solidity: function acrossV3Adapter() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) AcrossV3Adapter() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.AcrossV3Adapter(&_AcrossV3AdapterTest.CallOpts)
}

// AcrossV3Adapter is a free data retrieval call binding the contract method 0x3391c954.
//
// Solidity: function acrossV3Adapter() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) AcrossV3Adapter() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.AcrossV3Adapter(&_AcrossV3AdapterTest.CallOpts)
}

// DebridgeAdapter is a free data retrieval call binding the contract method 0x00a8194b.
//
// Solidity: function debridgeAdapter() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) DebridgeAdapter(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "debridgeAdapter")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// DebridgeAdapter is a free data retrieval call binding the contract method 0x00a8194b.
//
// Solidity: function debridgeAdapter() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) DebridgeAdapter() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.DebridgeAdapter(&_AcrossV3AdapterTest.CallOpts)
}

// DebridgeAdapter is a free data retrieval call binding the contract method 0x00a8194b.
//
// Solidity: function debridgeAdapter() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) DebridgeAdapter() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.DebridgeAdapter(&_AcrossV3AdapterTest.CallOpts)
}

// EnvOr is a free data retrieval call binding the contract method 0x4777f3cf.
//
// Solidity: function envOr(string name, bool defaultValue) view returns(bool value)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) EnvOr(opts *bind.CallOpts, name string, defaultValue bool) (bool, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "envOr", name, defaultValue)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// EnvOr is a free data retrieval call binding the contract method 0x4777f3cf.
//
// Solidity: function envOr(string name, bool defaultValue) view returns(bool value)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) EnvOr(name string, defaultValue bool) (bool, error) {
	return _AcrossV3AdapterTest.Contract.EnvOr(&_AcrossV3AdapterTest.CallOpts, name, defaultValue)
}

// EnvOr is a free data retrieval call binding the contract method 0x4777f3cf.
//
// Solidity: function envOr(string name, bool defaultValue) view returns(bool value)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) EnvOr(name string, defaultValue bool) (bool, error) {
	return _AcrossV3AdapterTest.Contract.EnvOr(&_AcrossV3AdapterTest.CallOpts, name, defaultValue)
}

// EnvOr0 is a free data retrieval call binding the contract method 0xd145736c.
//
// Solidity: function envOr(string name, string defaultValue) view returns(string value)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) EnvOr0(opts *bind.CallOpts, name string, defaultValue string) (string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "envOr0", name, defaultValue)

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// EnvOr0 is a free data retrieval call binding the contract method 0xd145736c.
//
// Solidity: function envOr(string name, string defaultValue) view returns(string value)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) EnvOr0(name string, defaultValue string) (string, error) {
	return _AcrossV3AdapterTest.Contract.EnvOr0(&_AcrossV3AdapterTest.CallOpts, name, defaultValue)
}

// EnvOr0 is a free data retrieval call binding the contract method 0xd145736c.
//
// Solidity: function envOr(string name, string defaultValue) view returns(string value)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) EnvOr0(name string, defaultValue string) (string, error) {
	return _AcrossV3AdapterTest.Contract.EnvOr0(&_AcrossV3AdapterTest.CallOpts, name, defaultValue)
}

// ExcludeArtifacts is a free data retrieval call binding the contract method 0xb5508aa9.
//
// Solidity: function excludeArtifacts() view returns(string[] excludedArtifacts_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ExcludeArtifacts(opts *bind.CallOpts) ([]string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "excludeArtifacts")

	if err != nil {
		return *new([]string), err
	}

	out0 := *abi.ConvertType(out[0], new([]string)).(*[]string)

	return out0, err

}

// ExcludeArtifacts is a free data retrieval call binding the contract method 0xb5508aa9.
//
// Solidity: function excludeArtifacts() view returns(string[] excludedArtifacts_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ExcludeArtifacts() ([]string, error) {
	return _AcrossV3AdapterTest.Contract.ExcludeArtifacts(&_AcrossV3AdapterTest.CallOpts)
}

// ExcludeArtifacts is a free data retrieval call binding the contract method 0xb5508aa9.
//
// Solidity: function excludeArtifacts() view returns(string[] excludedArtifacts_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ExcludeArtifacts() ([]string, error) {
	return _AcrossV3AdapterTest.Contract.ExcludeArtifacts(&_AcrossV3AdapterTest.CallOpts)
}

// ExcludeContracts is a free data retrieval call binding the contract method 0xe20c9f71.
//
// Solidity: function excludeContracts() view returns(address[] excludedContracts_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ExcludeContracts(opts *bind.CallOpts) ([]common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "excludeContracts")

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// ExcludeContracts is a free data retrieval call binding the contract method 0xe20c9f71.
//
// Solidity: function excludeContracts() view returns(address[] excludedContracts_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ExcludeContracts() ([]common.Address, error) {
	return _AcrossV3AdapterTest.Contract.ExcludeContracts(&_AcrossV3AdapterTest.CallOpts)
}

// ExcludeContracts is a free data retrieval call binding the contract method 0xe20c9f71.
//
// Solidity: function excludeContracts() view returns(address[] excludedContracts_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ExcludeContracts() ([]common.Address, error) {
	return _AcrossV3AdapterTest.Contract.ExcludeContracts(&_AcrossV3AdapterTest.CallOpts)
}

// ExcludeSelectors is a free data retrieval call binding the contract method 0xb0464fdc.
//
// Solidity: function excludeSelectors() view returns((address,bytes4[])[] excludedSelectors_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ExcludeSelectors(opts *bind.CallOpts) ([]StdInvariantFuzzSelector, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "excludeSelectors")

	if err != nil {
		return *new([]StdInvariantFuzzSelector), err
	}

	out0 := *abi.ConvertType(out[0], new([]StdInvariantFuzzSelector)).(*[]StdInvariantFuzzSelector)

	return out0, err

}

// ExcludeSelectors is a free data retrieval call binding the contract method 0xb0464fdc.
//
// Solidity: function excludeSelectors() view returns((address,bytes4[])[] excludedSelectors_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ExcludeSelectors() ([]StdInvariantFuzzSelector, error) {
	return _AcrossV3AdapterTest.Contract.ExcludeSelectors(&_AcrossV3AdapterTest.CallOpts)
}

// ExcludeSelectors is a free data retrieval call binding the contract method 0xb0464fdc.
//
// Solidity: function excludeSelectors() view returns((address,bytes4[])[] excludedSelectors_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ExcludeSelectors() ([]StdInvariantFuzzSelector, error) {
	return _AcrossV3AdapterTest.Contract.ExcludeSelectors(&_AcrossV3AdapterTest.CallOpts)
}

// ExcludeSenders is a free data retrieval call binding the contract method 0x1ed7831c.
//
// Solidity: function excludeSenders() view returns(address[] excludedSenders_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ExcludeSenders(opts *bind.CallOpts) ([]common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "excludeSenders")

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// ExcludeSenders is a free data retrieval call binding the contract method 0x1ed7831c.
//
// Solidity: function excludeSenders() view returns(address[] excludedSenders_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ExcludeSenders() ([]common.Address, error) {
	return _AcrossV3AdapterTest.Contract.ExcludeSenders(&_AcrossV3AdapterTest.CallOpts)
}

// ExcludeSenders is a free data retrieval call binding the contract method 0x1ed7831c.
//
// Solidity: function excludeSenders() view returns(address[] excludedSenders_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ExcludeSenders() ([]common.Address, error) {
	return _AcrossV3AdapterTest.Contract.ExcludeSenders(&_AcrossV3AdapterTest.CallOpts)
}

// Failed is a free data retrieval call binding the contract method 0xba414fa6.
//
// Solidity: function failed() view returns(bool)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) Failed(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "failed")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Failed is a free data retrieval call binding the contract method 0xba414fa6.
//
// Solidity: function failed() view returns(bool)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) Failed() (bool, error) {
	return _AcrossV3AdapterTest.Contract.Failed(&_AcrossV3AdapterTest.CallOpts)
}

// Failed is a free data retrieval call binding the contract method 0xba414fa6.
//
// Solidity: function failed() view returns(bool)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) Failed() (bool, error) {
	return _AcrossV3AdapterTest.Contract.Failed(&_AcrossV3AdapterTest.CallOpts)
}

// MockDlnDestination is a free data retrieval call binding the contract method 0x81f341b5.
//
// Solidity: function mockDlnDestination() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MockDlnDestination(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "mockDlnDestination")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MockDlnDestination is a free data retrieval call binding the contract method 0x81f341b5.
//
// Solidity: function mockDlnDestination() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MockDlnDestination() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MockDlnDestination(&_AcrossV3AdapterTest.CallOpts)
}

// MockDlnDestination is a free data retrieval call binding the contract method 0x81f341b5.
//
// Solidity: function mockDlnDestination() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MockDlnDestination() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MockDlnDestination(&_AcrossV3AdapterTest.CallOpts)
}

// MockERC20 is a free data retrieval call binding the contract method 0x5a744d91.
//
// Solidity: function mockERC20() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) MockERC20(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "mockERC20")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// MockERC20 is a free data retrieval call binding the contract method 0x5a744d91.
//
// Solidity: function mockERC20() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) MockERC20() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MockERC20(&_AcrossV3AdapterTest.CallOpts)
}

// MockERC20 is a free data retrieval call binding the contract method 0x5a744d91.
//
// Solidity: function mockERC20() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) MockERC20() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.MockERC20(&_AcrossV3AdapterTest.CallOpts)
}

// ProcessBridgedExecution is a free data retrieval call binding the contract method 0xed71d9d1.
//
// Solidity: function processBridgedExecution(address , address , address[] , uint256[] , bytes , bytes , bytes ) pure returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) ProcessBridgedExecution(opts *bind.CallOpts, arg0 common.Address, arg1 common.Address, arg2 []common.Address, arg3 []*big.Int, arg4 []byte, arg5 []byte, arg6 []byte) error {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "processBridgedExecution", arg0, arg1, arg2, arg3, arg4, arg5, arg6)

	if err != nil {
		return err
	}

	return err

}

// ProcessBridgedExecution is a free data retrieval call binding the contract method 0xed71d9d1.
//
// Solidity: function processBridgedExecution(address , address , address[] , uint256[] , bytes , bytes , bytes ) pure returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) ProcessBridgedExecution(arg0 common.Address, arg1 common.Address, arg2 []common.Address, arg3 []*big.Int, arg4 []byte, arg5 []byte, arg6 []byte) error {
	return _AcrossV3AdapterTest.Contract.ProcessBridgedExecution(&_AcrossV3AdapterTest.CallOpts, arg0, arg1, arg2, arg3, arg4, arg5, arg6)
}

// ProcessBridgedExecution is a free data retrieval call binding the contract method 0xed71d9d1.
//
// Solidity: function processBridgedExecution(address , address , address[] , uint256[] , bytes , bytes , bytes ) pure returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) ProcessBridgedExecution(arg0 common.Address, arg1 common.Address, arg2 []common.Address, arg3 []*big.Int, arg4 []byte, arg5 []byte, arg6 []byte) error {
	return _AcrossV3AdapterTest.Contract.ProcessBridgedExecution(&_AcrossV3AdapterTest.CallOpts, arg0, arg1, arg2, arg3, arg4, arg5, arg6)
}

// TargetArtifactSelectors is a free data retrieval call binding the contract method 0x66d9a9a0.
//
// Solidity: function targetArtifactSelectors() view returns((string,bytes4[])[] targetedArtifactSelectors_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) TargetArtifactSelectors(opts *bind.CallOpts) ([]StdInvariantFuzzArtifactSelector, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "targetArtifactSelectors")

	if err != nil {
		return *new([]StdInvariantFuzzArtifactSelector), err
	}

	out0 := *abi.ConvertType(out[0], new([]StdInvariantFuzzArtifactSelector)).(*[]StdInvariantFuzzArtifactSelector)

	return out0, err

}

// TargetArtifactSelectors is a free data retrieval call binding the contract method 0x66d9a9a0.
//
// Solidity: function targetArtifactSelectors() view returns((string,bytes4[])[] targetedArtifactSelectors_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) TargetArtifactSelectors() ([]StdInvariantFuzzArtifactSelector, error) {
	return _AcrossV3AdapterTest.Contract.TargetArtifactSelectors(&_AcrossV3AdapterTest.CallOpts)
}

// TargetArtifactSelectors is a free data retrieval call binding the contract method 0x66d9a9a0.
//
// Solidity: function targetArtifactSelectors() view returns((string,bytes4[])[] targetedArtifactSelectors_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) TargetArtifactSelectors() ([]StdInvariantFuzzArtifactSelector, error) {
	return _AcrossV3AdapterTest.Contract.TargetArtifactSelectors(&_AcrossV3AdapterTest.CallOpts)
}

// TargetArtifacts is a free data retrieval call binding the contract method 0x85226c81.
//
// Solidity: function targetArtifacts() view returns(string[] targetedArtifacts_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) TargetArtifacts(opts *bind.CallOpts) ([]string, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "targetArtifacts")

	if err != nil {
		return *new([]string), err
	}

	out0 := *abi.ConvertType(out[0], new([]string)).(*[]string)

	return out0, err

}

// TargetArtifacts is a free data retrieval call binding the contract method 0x85226c81.
//
// Solidity: function targetArtifacts() view returns(string[] targetedArtifacts_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) TargetArtifacts() ([]string, error) {
	return _AcrossV3AdapterTest.Contract.TargetArtifacts(&_AcrossV3AdapterTest.CallOpts)
}

// TargetArtifacts is a free data retrieval call binding the contract method 0x85226c81.
//
// Solidity: function targetArtifacts() view returns(string[] targetedArtifacts_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) TargetArtifacts() ([]string, error) {
	return _AcrossV3AdapterTest.Contract.TargetArtifacts(&_AcrossV3AdapterTest.CallOpts)
}

// TargetContracts is a free data retrieval call binding the contract method 0x3f7286f4.
//
// Solidity: function targetContracts() view returns(address[] targetedContracts_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) TargetContracts(opts *bind.CallOpts) ([]common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "targetContracts")

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// TargetContracts is a free data retrieval call binding the contract method 0x3f7286f4.
//
// Solidity: function targetContracts() view returns(address[] targetedContracts_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) TargetContracts() ([]common.Address, error) {
	return _AcrossV3AdapterTest.Contract.TargetContracts(&_AcrossV3AdapterTest.CallOpts)
}

// TargetContracts is a free data retrieval call binding the contract method 0x3f7286f4.
//
// Solidity: function targetContracts() view returns(address[] targetedContracts_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) TargetContracts() ([]common.Address, error) {
	return _AcrossV3AdapterTest.Contract.TargetContracts(&_AcrossV3AdapterTest.CallOpts)
}

// TargetInterfaces is a free data retrieval call binding the contract method 0x2ade3880.
//
// Solidity: function targetInterfaces() view returns((address,string[])[] targetedInterfaces_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) TargetInterfaces(opts *bind.CallOpts) ([]StdInvariantFuzzInterface, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "targetInterfaces")

	if err != nil {
		return *new([]StdInvariantFuzzInterface), err
	}

	out0 := *abi.ConvertType(out[0], new([]StdInvariantFuzzInterface)).(*[]StdInvariantFuzzInterface)

	return out0, err

}

// TargetInterfaces is a free data retrieval call binding the contract method 0x2ade3880.
//
// Solidity: function targetInterfaces() view returns((address,string[])[] targetedInterfaces_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) TargetInterfaces() ([]StdInvariantFuzzInterface, error) {
	return _AcrossV3AdapterTest.Contract.TargetInterfaces(&_AcrossV3AdapterTest.CallOpts)
}

// TargetInterfaces is a free data retrieval call binding the contract method 0x2ade3880.
//
// Solidity: function targetInterfaces() view returns((address,string[])[] targetedInterfaces_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) TargetInterfaces() ([]StdInvariantFuzzInterface, error) {
	return _AcrossV3AdapterTest.Contract.TargetInterfaces(&_AcrossV3AdapterTest.CallOpts)
}

// TargetSelectors is a free data retrieval call binding the contract method 0x916a17c6.
//
// Solidity: function targetSelectors() view returns((address,bytes4[])[] targetedSelectors_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) TargetSelectors(opts *bind.CallOpts) ([]StdInvariantFuzzSelector, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "targetSelectors")

	if err != nil {
		return *new([]StdInvariantFuzzSelector), err
	}

	out0 := *abi.ConvertType(out[0], new([]StdInvariantFuzzSelector)).(*[]StdInvariantFuzzSelector)

	return out0, err

}

// TargetSelectors is a free data retrieval call binding the contract method 0x916a17c6.
//
// Solidity: function targetSelectors() view returns((address,bytes4[])[] targetedSelectors_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) TargetSelectors() ([]StdInvariantFuzzSelector, error) {
	return _AcrossV3AdapterTest.Contract.TargetSelectors(&_AcrossV3AdapterTest.CallOpts)
}

// TargetSelectors is a free data retrieval call binding the contract method 0x916a17c6.
//
// Solidity: function targetSelectors() view returns((address,bytes4[])[] targetedSelectors_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) TargetSelectors() ([]StdInvariantFuzzSelector, error) {
	return _AcrossV3AdapterTest.Contract.TargetSelectors(&_AcrossV3AdapterTest.CallOpts)
}

// TargetSenders is a free data retrieval call binding the contract method 0x3e5e3c23.
//
// Solidity: function targetSenders() view returns(address[] targetedSenders_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) TargetSenders(opts *bind.CallOpts) ([]common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "targetSenders")

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// TargetSenders is a free data retrieval call binding the contract method 0x3e5e3c23.
//
// Solidity: function targetSenders() view returns(address[] targetedSenders_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) TargetSenders() ([]common.Address, error) {
	return _AcrossV3AdapterTest.Contract.TargetSenders(&_AcrossV3AdapterTest.CallOpts)
}

// TargetSenders is a free data retrieval call binding the contract method 0x3e5e3c23.
//
// Solidity: function targetSenders() view returns(address[] targetedSenders_)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) TargetSenders() ([]common.Address, error) {
	return _AcrossV3AdapterTest.Contract.TargetSenders(&_AcrossV3AdapterTest.CallOpts)
}

// User1 is a free data retrieval call binding the contract method 0xac1717b0.
//
// Solidity: function user1() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) User1(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "user1")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// User1 is a free data retrieval call binding the contract method 0xac1717b0.
//
// Solidity: function user1() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) User1() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.User1(&_AcrossV3AdapterTest.CallOpts)
}

// User1 is a free data retrieval call binding the contract method 0xac1717b0.
//
// Solidity: function user1() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) User1() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.User1(&_AcrossV3AdapterTest.CallOpts)
}

// User2 is a free data retrieval call binding the contract method 0xb9edb1af.
//
// Solidity: function user2() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) User2(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "user2")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// User2 is a free data retrieval call binding the contract method 0xb9edb1af.
//
// Solidity: function user2() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) User2() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.User2(&_AcrossV3AdapterTest.CallOpts)
}

// User2 is a free data retrieval call binding the contract method 0xb9edb1af.
//
// Solidity: function user2() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) User2() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.User2(&_AcrossV3AdapterTest.CallOpts)
}

// User3 is a free data retrieval call binding the contract method 0x703ce4af.
//
// Solidity: function user3() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCaller) User3(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterTest.contract.Call(opts, &out, "user3")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// User3 is a free data retrieval call binding the contract method 0x703ce4af.
//
// Solidity: function user3() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) User3() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.User3(&_AcrossV3AdapterTest.CallOpts)
}

// User3 is a free data retrieval call binding the contract method 0x703ce4af.
//
// Solidity: function user3() view returns(address)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestCallerSession) User3() (common.Address, error) {
	return _AcrossV3AdapterTest.Contract.User3(&_AcrossV3AdapterTest.CallOpts)
}

// DeployAccounts is a paid mutator transaction binding the contract method 0xd9e4deb3.
//
// Solidity: function deployAccounts() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactor) DeployAccounts(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossV3AdapterTest.contract.Transact(opts, "deployAccounts")
}

// DeployAccounts is a paid mutator transaction binding the contract method 0xd9e4deb3.
//
// Solidity: function deployAccounts() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) DeployAccounts() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.DeployAccounts(&_AcrossV3AdapterTest.TransactOpts)
}

// DeployAccounts is a paid mutator transaction binding the contract method 0xd9e4deb3.
//
// Solidity: function deployAccounts() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactorSession) DeployAccounts() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.DeployAccounts(&_AcrossV3AdapterTest.TransactOpts)
}

// SetUp is a paid mutator transaction binding the contract method 0x0a9254e4.
//
// Solidity: function setUp() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactor) SetUp(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossV3AdapterTest.contract.Transact(opts, "setUp")
}

// SetUp is a paid mutator transaction binding the contract method 0x0a9254e4.
//
// Solidity: function setUp() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) SetUp() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.SetUp(&_AcrossV3AdapterTest.TransactOpts)
}

// SetUp is a paid mutator transaction binding the contract method 0x0a9254e4.
//
// Solidity: function setUp() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactorSession) SetUp() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.SetUp(&_AcrossV3AdapterTest.TransactOpts)
}

// StartStateDiffRecording is a paid mutator transaction binding the contract method 0xcf22e3c9.
//
// Solidity: function startStateDiffRecording() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactor) StartStateDiffRecording(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossV3AdapterTest.contract.Transact(opts, "startStateDiffRecording")
}

// StartStateDiffRecording is a paid mutator transaction binding the contract method 0xcf22e3c9.
//
// Solidity: function startStateDiffRecording() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) StartStateDiffRecording() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.StartStateDiffRecording(&_AcrossV3AdapterTest.TransactOpts)
}

// StartStateDiffRecording is a paid mutator transaction binding the contract method 0xcf22e3c9.
//
// Solidity: function startStateDiffRecording() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactorSession) StartStateDiffRecording() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.StartStateDiffRecording(&_AcrossV3AdapterTest.TransactOpts)
}

// TestConstructor is a paid mutator transaction binding the contract method 0x3c322dd3.
//
// Solidity: function test_Constructor() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactor) TestConstructor(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossV3AdapterTest.contract.Transact(opts, "test_Constructor")
}

// TestConstructor is a paid mutator transaction binding the contract method 0x3c322dd3.
//
// Solidity: function test_Constructor() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) TestConstructor() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.TestConstructor(&_AcrossV3AdapterTest.TransactOpts)
}

// TestConstructor is a paid mutator transaction binding the contract method 0x3c322dd3.
//
// Solidity: function test_Constructor() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactorSession) TestConstructor() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.TestConstructor(&_AcrossV3AdapterTest.TransactOpts)
}

// TestDebridgeConstructor is a paid mutator transaction binding the contract method 0x7f92de58.
//
// Solidity: function test_Debridge_Constructor() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactor) TestDebridgeConstructor(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossV3AdapterTest.contract.Transact(opts, "test_Debridge_Constructor")
}

// TestDebridgeConstructor is a paid mutator transaction binding the contract method 0x7f92de58.
//
// Solidity: function test_Debridge_Constructor() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) TestDebridgeConstructor() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.TestDebridgeConstructor(&_AcrossV3AdapterTest.TransactOpts)
}

// TestDebridgeConstructor is a paid mutator transaction binding the contract method 0x7f92de58.
//
// Solidity: function test_Debridge_Constructor() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactorSession) TestDebridgeConstructor() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.TestDebridgeConstructor(&_AcrossV3AdapterTest.TransactOpts)
}

// TestDebridgeHandleERC20 is a paid mutator transaction binding the contract method 0x7a8aa41f.
//
// Solidity: function test_Debridge_HandleERC20() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactor) TestDebridgeHandleERC20(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossV3AdapterTest.contract.Transact(opts, "test_Debridge_HandleERC20")
}

// TestDebridgeHandleERC20 is a paid mutator transaction binding the contract method 0x7a8aa41f.
//
// Solidity: function test_Debridge_HandleERC20() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) TestDebridgeHandleERC20() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.TestDebridgeHandleERC20(&_AcrossV3AdapterTest.TransactOpts)
}

// TestDebridgeHandleERC20 is a paid mutator transaction binding the contract method 0x7a8aa41f.
//
// Solidity: function test_Debridge_HandleERC20() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactorSession) TestDebridgeHandleERC20() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.TestDebridgeHandleERC20(&_AcrossV3AdapterTest.TransactOpts)
}

// TestDebridgeHandleEth is a paid mutator transaction binding the contract method 0xebb6dd6f.
//
// Solidity: function test_Debridge_HandleEth() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactor) TestDebridgeHandleEth(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossV3AdapterTest.contract.Transact(opts, "test_Debridge_HandleEth")
}

// TestDebridgeHandleEth is a paid mutator transaction binding the contract method 0xebb6dd6f.
//
// Solidity: function test_Debridge_HandleEth() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) TestDebridgeHandleEth() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.TestDebridgeHandleEth(&_AcrossV3AdapterTest.TransactOpts)
}

// TestDebridgeHandleEth is a paid mutator transaction binding the contract method 0xebb6dd6f.
//
// Solidity: function test_Debridge_HandleEth() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactorSession) TestDebridgeHandleEth() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.TestDebridgeHandleEth(&_AcrossV3AdapterTest.TransactOpts)
}

// TestDebridgeInvalidDecoding is a paid mutator transaction binding the contract method 0xac0457de.
//
// Solidity: function test_Debridge_InvalidDecoding() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactor) TestDebridgeInvalidDecoding(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossV3AdapterTest.contract.Transact(opts, "test_Debridge_InvalidDecoding")
}

// TestDebridgeInvalidDecoding is a paid mutator transaction binding the contract method 0xac0457de.
//
// Solidity: function test_Debridge_InvalidDecoding() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) TestDebridgeInvalidDecoding() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.TestDebridgeInvalidDecoding(&_AcrossV3AdapterTest.TransactOpts)
}

// TestDebridgeInvalidDecoding is a paid mutator transaction binding the contract method 0xac0457de.
//
// Solidity: function test_Debridge_InvalidDecoding() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactorSession) TestDebridgeInvalidDecoding() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.TestDebridgeInvalidDecoding(&_AcrossV3AdapterTest.TransactOpts)
}

// TestDebridgeInvalidEthRecipient is a paid mutator transaction binding the contract method 0xe636cd3b.
//
// Solidity: function test_Debridge_InvalidEthRecipient() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactor) TestDebridgeInvalidEthRecipient(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossV3AdapterTest.contract.Transact(opts, "test_Debridge_InvalidEthRecipient")
}

// TestDebridgeInvalidEthRecipient is a paid mutator transaction binding the contract method 0xe636cd3b.
//
// Solidity: function test_Debridge_InvalidEthRecipient() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) TestDebridgeInvalidEthRecipient() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.TestDebridgeInvalidEthRecipient(&_AcrossV3AdapterTest.TransactOpts)
}

// TestDebridgeInvalidEthRecipient is a paid mutator transaction binding the contract method 0xe636cd3b.
//
// Solidity: function test_Debridge_InvalidEthRecipient() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactorSession) TestDebridgeInvalidEthRecipient() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.TestDebridgeInvalidEthRecipient(&_AcrossV3AdapterTest.TransactOpts)
}

// TestDebridgeInvalidSender is a paid mutator transaction binding the contract method 0xcfec06fa.
//
// Solidity: function test_Debridge_InvalidSender() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactor) TestDebridgeInvalidSender(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossV3AdapterTest.contract.Transact(opts, "test_Debridge_InvalidSender")
}

// TestDebridgeInvalidSender is a paid mutator transaction binding the contract method 0xcfec06fa.
//
// Solidity: function test_Debridge_InvalidSender() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) TestDebridgeInvalidSender() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.TestDebridgeInvalidSender(&_AcrossV3AdapterTest.TransactOpts)
}

// TestDebridgeInvalidSender is a paid mutator transaction binding the contract method 0xcfec06fa.
//
// Solidity: function test_Debridge_InvalidSender() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactorSession) TestDebridgeInvalidSender() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.TestDebridgeInvalidSender(&_AcrossV3AdapterTest.TransactOpts)
}

// TestDebridgeInvalidToken is a paid mutator transaction binding the contract method 0x5a448e0f.
//
// Solidity: function test_Debridge_InvalidToken() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactor) TestDebridgeInvalidToken(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossV3AdapterTest.contract.Transact(opts, "test_Debridge_InvalidToken")
}

// TestDebridgeInvalidToken is a paid mutator transaction binding the contract method 0x5a448e0f.
//
// Solidity: function test_Debridge_InvalidToken() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) TestDebridgeInvalidToken() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.TestDebridgeInvalidToken(&_AcrossV3AdapterTest.TransactOpts)
}

// TestDebridgeInvalidToken is a paid mutator transaction binding the contract method 0x5a448e0f.
//
// Solidity: function test_Debridge_InvalidToken() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactorSession) TestDebridgeInvalidToken() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.TestDebridgeInvalidToken(&_AcrossV3AdapterTest.TransactOpts)
}

// TestHandle is a paid mutator transaction binding the contract method 0xab835c5c.
//
// Solidity: function test_Handle() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactor) TestHandle(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossV3AdapterTest.contract.Transact(opts, "test_Handle")
}

// TestHandle is a paid mutator transaction binding the contract method 0xab835c5c.
//
// Solidity: function test_Handle() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) TestHandle() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.TestHandle(&_AcrossV3AdapterTest.TransactOpts)
}

// TestHandle is a paid mutator transaction binding the contract method 0xab835c5c.
//
// Solidity: function test_Handle() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactorSession) TestHandle() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.TestHandle(&_AcrossV3AdapterTest.TransactOpts)
}

// TestInvalidDecoding is a paid mutator transaction binding the contract method 0x00aa9253.
//
// Solidity: function test_InvalidDecoding() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactor) TestInvalidDecoding(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossV3AdapterTest.contract.Transact(opts, "test_InvalidDecoding")
}

// TestInvalidDecoding is a paid mutator transaction binding the contract method 0x00aa9253.
//
// Solidity: function test_InvalidDecoding() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) TestInvalidDecoding() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.TestInvalidDecoding(&_AcrossV3AdapterTest.TransactOpts)
}

// TestInvalidDecoding is a paid mutator transaction binding the contract method 0x00aa9253.
//
// Solidity: function test_InvalidDecoding() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactorSession) TestInvalidDecoding() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.TestInvalidDecoding(&_AcrossV3AdapterTest.TransactOpts)
}

// TestInvalidSender is a paid mutator transaction binding the contract method 0xcfbecf5c.
//
// Solidity: function test_InvalidSender() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactor) TestInvalidSender(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossV3AdapterTest.contract.Transact(opts, "test_InvalidSender")
}

// TestInvalidSender is a paid mutator transaction binding the contract method 0xcfbecf5c.
//
// Solidity: function test_InvalidSender() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) TestInvalidSender() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.TestInvalidSender(&_AcrossV3AdapterTest.TransactOpts)
}

// TestInvalidSender is a paid mutator transaction binding the contract method 0xcfbecf5c.
//
// Solidity: function test_InvalidSender() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactorSession) TestInvalidSender() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.TestInvalidSender(&_AcrossV3AdapterTest.TransactOpts)
}

// TestInvalidToken is a paid mutator transaction binding the contract method 0x7698e0bd.
//
// Solidity: function test_InvalidToken() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactor) TestInvalidToken(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossV3AdapterTest.contract.Transact(opts, "test_InvalidToken")
}

// TestInvalidToken is a paid mutator transaction binding the contract method 0x7698e0bd.
//
// Solidity: function test_InvalidToken() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) TestInvalidToken() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.TestInvalidToken(&_AcrossV3AdapterTest.TransactOpts)
}

// TestInvalidToken is a paid mutator transaction binding the contract method 0x7698e0bd.
//
// Solidity: function test_InvalidToken() returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactorSession) TestInvalidToken() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.TestInvalidToken(&_AcrossV3AdapterTest.TransactOpts)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactor) Receive(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossV3AdapterTest.contract.RawTransact(opts, nil) // calldata is disallowed for receive function
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestSession) Receive() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.Receive(&_AcrossV3AdapterTest.TransactOpts)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_AcrossV3AdapterTest *AcrossV3AdapterTestTransactorSession) Receive() (*types.Transaction, error) {
	return _AcrossV3AdapterTest.Contract.Receive(&_AcrossV3AdapterTest.TransactOpts)
}

// AcrossV3AdapterTestSlotFoundIterator is returned from FilterSlotFound and is used to iterate over the raw logs and unpacked data for SlotFound events raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestSlotFoundIterator struct {
	Event *AcrossV3AdapterTestSlotFound // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterTestSlotFoundIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterTestSlotFound)
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
		it.Event = new(AcrossV3AdapterTestSlotFound)
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
func (it *AcrossV3AdapterTestSlotFoundIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterTestSlotFoundIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterTestSlotFound represents a SlotFound event raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestSlotFound struct {
	Who      common.Address
	Fsig     [4]byte
	KeysHash [32]byte
	Slot     *big.Int
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterSlotFound is a free log retrieval operation binding the contract event 0x9c9555b1e3102e3cf48f427d79cb678f5d9bd1ed0ad574389461e255f95170ed.
//
// Solidity: event SlotFound(address who, bytes4 fsig, bytes32 keysHash, uint256 slot)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) FilterSlotFound(opts *bind.FilterOpts) (*AcrossV3AdapterTestSlotFoundIterator, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.FilterLogs(opts, "SlotFound")
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestSlotFoundIterator{contract: _AcrossV3AdapterTest.contract, event: "SlotFound", logs: logs, sub: sub}, nil
}

// WatchSlotFound is a free log subscription operation binding the contract event 0x9c9555b1e3102e3cf48f427d79cb678f5d9bd1ed0ad574389461e255f95170ed.
//
// Solidity: event SlotFound(address who, bytes4 fsig, bytes32 keysHash, uint256 slot)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) WatchSlotFound(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterTestSlotFound) (event.Subscription, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.WatchLogs(opts, "SlotFound")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterTestSlotFound)
				if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "SlotFound", log); err != nil {
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
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) ParseSlotFound(log types.Log) (*AcrossV3AdapterTestSlotFound, error) {
	event := new(AcrossV3AdapterTestSlotFound)
	if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "SlotFound", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterTestWARNINGUninitedSlotIterator is returned from FilterWARNINGUninitedSlot and is used to iterate over the raw logs and unpacked data for WARNINGUninitedSlot events raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestWARNINGUninitedSlotIterator struct {
	Event *AcrossV3AdapterTestWARNINGUninitedSlot // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterTestWARNINGUninitedSlotIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterTestWARNINGUninitedSlot)
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
		it.Event = new(AcrossV3AdapterTestWARNINGUninitedSlot)
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
func (it *AcrossV3AdapterTestWARNINGUninitedSlotIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterTestWARNINGUninitedSlotIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterTestWARNINGUninitedSlot represents a WARNINGUninitedSlot event raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestWARNINGUninitedSlot struct {
	Who  common.Address
	Slot *big.Int
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterWARNINGUninitedSlot is a free log retrieval operation binding the contract event 0x080fc4a96620c4462e705b23f346413fe3796bb63c6f8d8591baec0e231577a5.
//
// Solidity: event WARNING_UninitedSlot(address who, uint256 slot)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) FilterWARNINGUninitedSlot(opts *bind.FilterOpts) (*AcrossV3AdapterTestWARNINGUninitedSlotIterator, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.FilterLogs(opts, "WARNING_UninitedSlot")
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestWARNINGUninitedSlotIterator{contract: _AcrossV3AdapterTest.contract, event: "WARNING_UninitedSlot", logs: logs, sub: sub}, nil
}

// WatchWARNINGUninitedSlot is a free log subscription operation binding the contract event 0x080fc4a96620c4462e705b23f346413fe3796bb63c6f8d8591baec0e231577a5.
//
// Solidity: event WARNING_UninitedSlot(address who, uint256 slot)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) WatchWARNINGUninitedSlot(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterTestWARNINGUninitedSlot) (event.Subscription, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.WatchLogs(opts, "WARNING_UninitedSlot")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterTestWARNINGUninitedSlot)
				if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "WARNING_UninitedSlot", log); err != nil {
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
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) ParseWARNINGUninitedSlot(log types.Log) (*AcrossV3AdapterTestWARNINGUninitedSlot, error) {
	event := new(AcrossV3AdapterTestWARNINGUninitedSlot)
	if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "WARNING_UninitedSlot", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterTestLogIterator is returned from FilterLog and is used to iterate over the raw logs and unpacked data for Log events raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogIterator struct {
	Event *AcrossV3AdapterTestLog // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterTestLogIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterTestLog)
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
		it.Event = new(AcrossV3AdapterTestLog)
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
func (it *AcrossV3AdapterTestLogIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterTestLogIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterTestLog represents a Log event raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLog struct {
	Arg0 string
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterLog is a free log retrieval operation binding the contract event 0x41304facd9323d75b11bcdd609cb38effffdb05710f7caf0e9b16c6d9d709f50.
//
// Solidity: event log(string arg0)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) FilterLog(opts *bind.FilterOpts) (*AcrossV3AdapterTestLogIterator, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.FilterLogs(opts, "log")
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestLogIterator{contract: _AcrossV3AdapterTest.contract, event: "log", logs: logs, sub: sub}, nil
}

// WatchLog is a free log subscription operation binding the contract event 0x41304facd9323d75b11bcdd609cb38effffdb05710f7caf0e9b16c6d9d709f50.
//
// Solidity: event log(string arg0)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) WatchLog(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterTestLog) (event.Subscription, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.WatchLogs(opts, "log")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterTestLog)
				if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log", log); err != nil {
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
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) ParseLog(log types.Log) (*AcrossV3AdapterTestLog, error) {
	event := new(AcrossV3AdapterTestLog)
	if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterTestLogAddressIterator is returned from FilterLogAddress and is used to iterate over the raw logs and unpacked data for LogAddress events raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogAddressIterator struct {
	Event *AcrossV3AdapterTestLogAddress // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterTestLogAddressIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterTestLogAddress)
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
		it.Event = new(AcrossV3AdapterTestLogAddress)
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
func (it *AcrossV3AdapterTestLogAddressIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterTestLogAddressIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterTestLogAddress represents a LogAddress event raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogAddress struct {
	Arg0 common.Address
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterLogAddress is a free log retrieval operation binding the contract event 0x7ae74c527414ae135fd97047b12921a5ec3911b804197855d67e25c7b75ee6f3.
//
// Solidity: event log_address(address arg0)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) FilterLogAddress(opts *bind.FilterOpts) (*AcrossV3AdapterTestLogAddressIterator, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.FilterLogs(opts, "log_address")
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestLogAddressIterator{contract: _AcrossV3AdapterTest.contract, event: "log_address", logs: logs, sub: sub}, nil
}

// WatchLogAddress is a free log subscription operation binding the contract event 0x7ae74c527414ae135fd97047b12921a5ec3911b804197855d67e25c7b75ee6f3.
//
// Solidity: event log_address(address arg0)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) WatchLogAddress(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterTestLogAddress) (event.Subscription, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.WatchLogs(opts, "log_address")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterTestLogAddress)
				if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_address", log); err != nil {
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
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) ParseLogAddress(log types.Log) (*AcrossV3AdapterTestLogAddress, error) {
	event := new(AcrossV3AdapterTestLogAddress)
	if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_address", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterTestLogArrayIterator is returned from FilterLogArray and is used to iterate over the raw logs and unpacked data for LogArray events raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogArrayIterator struct {
	Event *AcrossV3AdapterTestLogArray // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterTestLogArrayIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterTestLogArray)
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
		it.Event = new(AcrossV3AdapterTestLogArray)
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
func (it *AcrossV3AdapterTestLogArrayIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterTestLogArrayIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterTestLogArray represents a LogArray event raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogArray struct {
	Val []*big.Int
	Raw types.Log // Blockchain specific contextual infos
}

// FilterLogArray is a free log retrieval operation binding the contract event 0xfb102865d50addddf69da9b5aa1bced66c80cf869a5c8d0471a467e18ce9cab1.
//
// Solidity: event log_array(uint256[] val)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) FilterLogArray(opts *bind.FilterOpts) (*AcrossV3AdapterTestLogArrayIterator, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.FilterLogs(opts, "log_array")
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestLogArrayIterator{contract: _AcrossV3AdapterTest.contract, event: "log_array", logs: logs, sub: sub}, nil
}

// WatchLogArray is a free log subscription operation binding the contract event 0xfb102865d50addddf69da9b5aa1bced66c80cf869a5c8d0471a467e18ce9cab1.
//
// Solidity: event log_array(uint256[] val)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) WatchLogArray(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterTestLogArray) (event.Subscription, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.WatchLogs(opts, "log_array")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterTestLogArray)
				if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_array", log); err != nil {
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
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) ParseLogArray(log types.Log) (*AcrossV3AdapterTestLogArray, error) {
	event := new(AcrossV3AdapterTestLogArray)
	if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_array", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterTestLogArray0Iterator is returned from FilterLogArray0 and is used to iterate over the raw logs and unpacked data for LogArray0 events raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogArray0Iterator struct {
	Event *AcrossV3AdapterTestLogArray0 // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterTestLogArray0Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterTestLogArray0)
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
		it.Event = new(AcrossV3AdapterTestLogArray0)
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
func (it *AcrossV3AdapterTestLogArray0Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterTestLogArray0Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterTestLogArray0 represents a LogArray0 event raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogArray0 struct {
	Val []*big.Int
	Raw types.Log // Blockchain specific contextual infos
}

// FilterLogArray0 is a free log retrieval operation binding the contract event 0x890a82679b470f2bd82816ed9b161f97d8b967f37fa3647c21d5bf39749e2dd5.
//
// Solidity: event log_array(int256[] val)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) FilterLogArray0(opts *bind.FilterOpts) (*AcrossV3AdapterTestLogArray0Iterator, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.FilterLogs(opts, "log_array0")
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestLogArray0Iterator{contract: _AcrossV3AdapterTest.contract, event: "log_array0", logs: logs, sub: sub}, nil
}

// WatchLogArray0 is a free log subscription operation binding the contract event 0x890a82679b470f2bd82816ed9b161f97d8b967f37fa3647c21d5bf39749e2dd5.
//
// Solidity: event log_array(int256[] val)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) WatchLogArray0(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterTestLogArray0) (event.Subscription, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.WatchLogs(opts, "log_array0")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterTestLogArray0)
				if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_array0", log); err != nil {
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
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) ParseLogArray0(log types.Log) (*AcrossV3AdapterTestLogArray0, error) {
	event := new(AcrossV3AdapterTestLogArray0)
	if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_array0", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterTestLogArray1Iterator is returned from FilterLogArray1 and is used to iterate over the raw logs and unpacked data for LogArray1 events raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogArray1Iterator struct {
	Event *AcrossV3AdapterTestLogArray1 // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterTestLogArray1Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterTestLogArray1)
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
		it.Event = new(AcrossV3AdapterTestLogArray1)
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
func (it *AcrossV3AdapterTestLogArray1Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterTestLogArray1Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterTestLogArray1 represents a LogArray1 event raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogArray1 struct {
	Val []common.Address
	Raw types.Log // Blockchain specific contextual infos
}

// FilterLogArray1 is a free log retrieval operation binding the contract event 0x40e1840f5769073d61bd01372d9b75baa9842d5629a0c99ff103be1178a8e9e2.
//
// Solidity: event log_array(address[] val)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) FilterLogArray1(opts *bind.FilterOpts) (*AcrossV3AdapterTestLogArray1Iterator, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.FilterLogs(opts, "log_array1")
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestLogArray1Iterator{contract: _AcrossV3AdapterTest.contract, event: "log_array1", logs: logs, sub: sub}, nil
}

// WatchLogArray1 is a free log subscription operation binding the contract event 0x40e1840f5769073d61bd01372d9b75baa9842d5629a0c99ff103be1178a8e9e2.
//
// Solidity: event log_array(address[] val)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) WatchLogArray1(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterTestLogArray1) (event.Subscription, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.WatchLogs(opts, "log_array1")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterTestLogArray1)
				if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_array1", log); err != nil {
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
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) ParseLogArray1(log types.Log) (*AcrossV3AdapterTestLogArray1, error) {
	event := new(AcrossV3AdapterTestLogArray1)
	if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_array1", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterTestLogBytesIterator is returned from FilterLogBytes and is used to iterate over the raw logs and unpacked data for LogBytes events raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogBytesIterator struct {
	Event *AcrossV3AdapterTestLogBytes // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterTestLogBytesIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterTestLogBytes)
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
		it.Event = new(AcrossV3AdapterTestLogBytes)
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
func (it *AcrossV3AdapterTestLogBytesIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterTestLogBytesIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterTestLogBytes represents a LogBytes event raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogBytes struct {
	Arg0 []byte
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterLogBytes is a free log retrieval operation binding the contract event 0x23b62ad0584d24a75f0bf3560391ef5659ec6db1269c56e11aa241d637f19b20.
//
// Solidity: event log_bytes(bytes arg0)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) FilterLogBytes(opts *bind.FilterOpts) (*AcrossV3AdapterTestLogBytesIterator, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.FilterLogs(opts, "log_bytes")
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestLogBytesIterator{contract: _AcrossV3AdapterTest.contract, event: "log_bytes", logs: logs, sub: sub}, nil
}

// WatchLogBytes is a free log subscription operation binding the contract event 0x23b62ad0584d24a75f0bf3560391ef5659ec6db1269c56e11aa241d637f19b20.
//
// Solidity: event log_bytes(bytes arg0)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) WatchLogBytes(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterTestLogBytes) (event.Subscription, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.WatchLogs(opts, "log_bytes")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterTestLogBytes)
				if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_bytes", log); err != nil {
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
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) ParseLogBytes(log types.Log) (*AcrossV3AdapterTestLogBytes, error) {
	event := new(AcrossV3AdapterTestLogBytes)
	if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_bytes", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterTestLogBytes32Iterator is returned from FilterLogBytes32 and is used to iterate over the raw logs and unpacked data for LogBytes32 events raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogBytes32Iterator struct {
	Event *AcrossV3AdapterTestLogBytes32 // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterTestLogBytes32Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterTestLogBytes32)
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
		it.Event = new(AcrossV3AdapterTestLogBytes32)
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
func (it *AcrossV3AdapterTestLogBytes32Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterTestLogBytes32Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterTestLogBytes32 represents a LogBytes32 event raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogBytes32 struct {
	Arg0 [32]byte
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterLogBytes32 is a free log retrieval operation binding the contract event 0xe81699b85113eea1c73e10588b2b035e55893369632173afd43feb192fac64e3.
//
// Solidity: event log_bytes32(bytes32 arg0)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) FilterLogBytes32(opts *bind.FilterOpts) (*AcrossV3AdapterTestLogBytes32Iterator, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.FilterLogs(opts, "log_bytes32")
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestLogBytes32Iterator{contract: _AcrossV3AdapterTest.contract, event: "log_bytes32", logs: logs, sub: sub}, nil
}

// WatchLogBytes32 is a free log subscription operation binding the contract event 0xe81699b85113eea1c73e10588b2b035e55893369632173afd43feb192fac64e3.
//
// Solidity: event log_bytes32(bytes32 arg0)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) WatchLogBytes32(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterTestLogBytes32) (event.Subscription, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.WatchLogs(opts, "log_bytes32")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterTestLogBytes32)
				if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_bytes32", log); err != nil {
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
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) ParseLogBytes32(log types.Log) (*AcrossV3AdapterTestLogBytes32, error) {
	event := new(AcrossV3AdapterTestLogBytes32)
	if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_bytes32", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterTestLogIntIterator is returned from FilterLogInt and is used to iterate over the raw logs and unpacked data for LogInt events raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogIntIterator struct {
	Event *AcrossV3AdapterTestLogInt // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterTestLogIntIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterTestLogInt)
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
		it.Event = new(AcrossV3AdapterTestLogInt)
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
func (it *AcrossV3AdapterTestLogIntIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterTestLogIntIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterTestLogInt represents a LogInt event raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogInt struct {
	Arg0 *big.Int
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterLogInt is a free log retrieval operation binding the contract event 0x0eb5d52624c8d28ada9fc55a8c502ed5aa3fbe2fb6e91b71b5f376882b1d2fb8.
//
// Solidity: event log_int(int256 arg0)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) FilterLogInt(opts *bind.FilterOpts) (*AcrossV3AdapterTestLogIntIterator, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.FilterLogs(opts, "log_int")
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestLogIntIterator{contract: _AcrossV3AdapterTest.contract, event: "log_int", logs: logs, sub: sub}, nil
}

// WatchLogInt is a free log subscription operation binding the contract event 0x0eb5d52624c8d28ada9fc55a8c502ed5aa3fbe2fb6e91b71b5f376882b1d2fb8.
//
// Solidity: event log_int(int256 arg0)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) WatchLogInt(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterTestLogInt) (event.Subscription, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.WatchLogs(opts, "log_int")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterTestLogInt)
				if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_int", log); err != nil {
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
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) ParseLogInt(log types.Log) (*AcrossV3AdapterTestLogInt, error) {
	event := new(AcrossV3AdapterTestLogInt)
	if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_int", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterTestLogNamedAddressIterator is returned from FilterLogNamedAddress and is used to iterate over the raw logs and unpacked data for LogNamedAddress events raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogNamedAddressIterator struct {
	Event *AcrossV3AdapterTestLogNamedAddress // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterTestLogNamedAddressIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterTestLogNamedAddress)
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
		it.Event = new(AcrossV3AdapterTestLogNamedAddress)
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
func (it *AcrossV3AdapterTestLogNamedAddressIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterTestLogNamedAddressIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterTestLogNamedAddress represents a LogNamedAddress event raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogNamedAddress struct {
	Key string
	Val common.Address
	Raw types.Log // Blockchain specific contextual infos
}

// FilterLogNamedAddress is a free log retrieval operation binding the contract event 0x9c4e8541ca8f0dc1c413f9108f66d82d3cecb1bddbce437a61caa3175c4cc96f.
//
// Solidity: event log_named_address(string key, address val)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) FilterLogNamedAddress(opts *bind.FilterOpts) (*AcrossV3AdapterTestLogNamedAddressIterator, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.FilterLogs(opts, "log_named_address")
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestLogNamedAddressIterator{contract: _AcrossV3AdapterTest.contract, event: "log_named_address", logs: logs, sub: sub}, nil
}

// WatchLogNamedAddress is a free log subscription operation binding the contract event 0x9c4e8541ca8f0dc1c413f9108f66d82d3cecb1bddbce437a61caa3175c4cc96f.
//
// Solidity: event log_named_address(string key, address val)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) WatchLogNamedAddress(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterTestLogNamedAddress) (event.Subscription, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.WatchLogs(opts, "log_named_address")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterTestLogNamedAddress)
				if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_named_address", log); err != nil {
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
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) ParseLogNamedAddress(log types.Log) (*AcrossV3AdapterTestLogNamedAddress, error) {
	event := new(AcrossV3AdapterTestLogNamedAddress)
	if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_named_address", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterTestLogNamedArrayIterator is returned from FilterLogNamedArray and is used to iterate over the raw logs and unpacked data for LogNamedArray events raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogNamedArrayIterator struct {
	Event *AcrossV3AdapterTestLogNamedArray // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterTestLogNamedArrayIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterTestLogNamedArray)
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
		it.Event = new(AcrossV3AdapterTestLogNamedArray)
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
func (it *AcrossV3AdapterTestLogNamedArrayIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterTestLogNamedArrayIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterTestLogNamedArray represents a LogNamedArray event raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogNamedArray struct {
	Key string
	Val []*big.Int
	Raw types.Log // Blockchain specific contextual infos
}

// FilterLogNamedArray is a free log retrieval operation binding the contract event 0x00aaa39c9ffb5f567a4534380c737075702e1f7f14107fc95328e3b56c0325fb.
//
// Solidity: event log_named_array(string key, uint256[] val)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) FilterLogNamedArray(opts *bind.FilterOpts) (*AcrossV3AdapterTestLogNamedArrayIterator, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.FilterLogs(opts, "log_named_array")
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestLogNamedArrayIterator{contract: _AcrossV3AdapterTest.contract, event: "log_named_array", logs: logs, sub: sub}, nil
}

// WatchLogNamedArray is a free log subscription operation binding the contract event 0x00aaa39c9ffb5f567a4534380c737075702e1f7f14107fc95328e3b56c0325fb.
//
// Solidity: event log_named_array(string key, uint256[] val)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) WatchLogNamedArray(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterTestLogNamedArray) (event.Subscription, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.WatchLogs(opts, "log_named_array")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterTestLogNamedArray)
				if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_named_array", log); err != nil {
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
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) ParseLogNamedArray(log types.Log) (*AcrossV3AdapterTestLogNamedArray, error) {
	event := new(AcrossV3AdapterTestLogNamedArray)
	if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_named_array", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterTestLogNamedArray0Iterator is returned from FilterLogNamedArray0 and is used to iterate over the raw logs and unpacked data for LogNamedArray0 events raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogNamedArray0Iterator struct {
	Event *AcrossV3AdapterTestLogNamedArray0 // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterTestLogNamedArray0Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterTestLogNamedArray0)
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
		it.Event = new(AcrossV3AdapterTestLogNamedArray0)
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
func (it *AcrossV3AdapterTestLogNamedArray0Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterTestLogNamedArray0Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterTestLogNamedArray0 represents a LogNamedArray0 event raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogNamedArray0 struct {
	Key string
	Val []*big.Int
	Raw types.Log // Blockchain specific contextual infos
}

// FilterLogNamedArray0 is a free log retrieval operation binding the contract event 0xa73eda09662f46dde729be4611385ff34fe6c44fbbc6f7e17b042b59a3445b57.
//
// Solidity: event log_named_array(string key, int256[] val)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) FilterLogNamedArray0(opts *bind.FilterOpts) (*AcrossV3AdapterTestLogNamedArray0Iterator, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.FilterLogs(opts, "log_named_array0")
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestLogNamedArray0Iterator{contract: _AcrossV3AdapterTest.contract, event: "log_named_array0", logs: logs, sub: sub}, nil
}

// WatchLogNamedArray0 is a free log subscription operation binding the contract event 0xa73eda09662f46dde729be4611385ff34fe6c44fbbc6f7e17b042b59a3445b57.
//
// Solidity: event log_named_array(string key, int256[] val)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) WatchLogNamedArray0(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterTestLogNamedArray0) (event.Subscription, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.WatchLogs(opts, "log_named_array0")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterTestLogNamedArray0)
				if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_named_array0", log); err != nil {
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
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) ParseLogNamedArray0(log types.Log) (*AcrossV3AdapterTestLogNamedArray0, error) {
	event := new(AcrossV3AdapterTestLogNamedArray0)
	if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_named_array0", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterTestLogNamedArray1Iterator is returned from FilterLogNamedArray1 and is used to iterate over the raw logs and unpacked data for LogNamedArray1 events raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogNamedArray1Iterator struct {
	Event *AcrossV3AdapterTestLogNamedArray1 // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterTestLogNamedArray1Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterTestLogNamedArray1)
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
		it.Event = new(AcrossV3AdapterTestLogNamedArray1)
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
func (it *AcrossV3AdapterTestLogNamedArray1Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterTestLogNamedArray1Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterTestLogNamedArray1 represents a LogNamedArray1 event raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogNamedArray1 struct {
	Key string
	Val []common.Address
	Raw types.Log // Blockchain specific contextual infos
}

// FilterLogNamedArray1 is a free log retrieval operation binding the contract event 0x3bcfb2ae2e8d132dd1fce7cf278a9a19756a9fceabe470df3bdabb4bc577d1bd.
//
// Solidity: event log_named_array(string key, address[] val)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) FilterLogNamedArray1(opts *bind.FilterOpts) (*AcrossV3AdapterTestLogNamedArray1Iterator, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.FilterLogs(opts, "log_named_array1")
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestLogNamedArray1Iterator{contract: _AcrossV3AdapterTest.contract, event: "log_named_array1", logs: logs, sub: sub}, nil
}

// WatchLogNamedArray1 is a free log subscription operation binding the contract event 0x3bcfb2ae2e8d132dd1fce7cf278a9a19756a9fceabe470df3bdabb4bc577d1bd.
//
// Solidity: event log_named_array(string key, address[] val)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) WatchLogNamedArray1(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterTestLogNamedArray1) (event.Subscription, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.WatchLogs(opts, "log_named_array1")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterTestLogNamedArray1)
				if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_named_array1", log); err != nil {
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
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) ParseLogNamedArray1(log types.Log) (*AcrossV3AdapterTestLogNamedArray1, error) {
	event := new(AcrossV3AdapterTestLogNamedArray1)
	if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_named_array1", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterTestLogNamedBytesIterator is returned from FilterLogNamedBytes and is used to iterate over the raw logs and unpacked data for LogNamedBytes events raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogNamedBytesIterator struct {
	Event *AcrossV3AdapterTestLogNamedBytes // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterTestLogNamedBytesIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterTestLogNamedBytes)
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
		it.Event = new(AcrossV3AdapterTestLogNamedBytes)
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
func (it *AcrossV3AdapterTestLogNamedBytesIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterTestLogNamedBytesIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterTestLogNamedBytes represents a LogNamedBytes event raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogNamedBytes struct {
	Key string
	Val []byte
	Raw types.Log // Blockchain specific contextual infos
}

// FilterLogNamedBytes is a free log retrieval operation binding the contract event 0xd26e16cad4548705e4c9e2d94f98ee91c289085ee425594fd5635fa2964ccf18.
//
// Solidity: event log_named_bytes(string key, bytes val)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) FilterLogNamedBytes(opts *bind.FilterOpts) (*AcrossV3AdapterTestLogNamedBytesIterator, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.FilterLogs(opts, "log_named_bytes")
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestLogNamedBytesIterator{contract: _AcrossV3AdapterTest.contract, event: "log_named_bytes", logs: logs, sub: sub}, nil
}

// WatchLogNamedBytes is a free log subscription operation binding the contract event 0xd26e16cad4548705e4c9e2d94f98ee91c289085ee425594fd5635fa2964ccf18.
//
// Solidity: event log_named_bytes(string key, bytes val)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) WatchLogNamedBytes(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterTestLogNamedBytes) (event.Subscription, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.WatchLogs(opts, "log_named_bytes")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterTestLogNamedBytes)
				if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_named_bytes", log); err != nil {
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
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) ParseLogNamedBytes(log types.Log) (*AcrossV3AdapterTestLogNamedBytes, error) {
	event := new(AcrossV3AdapterTestLogNamedBytes)
	if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_named_bytes", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterTestLogNamedBytes32Iterator is returned from FilterLogNamedBytes32 and is used to iterate over the raw logs and unpacked data for LogNamedBytes32 events raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogNamedBytes32Iterator struct {
	Event *AcrossV3AdapterTestLogNamedBytes32 // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterTestLogNamedBytes32Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterTestLogNamedBytes32)
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
		it.Event = new(AcrossV3AdapterTestLogNamedBytes32)
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
func (it *AcrossV3AdapterTestLogNamedBytes32Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterTestLogNamedBytes32Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterTestLogNamedBytes32 represents a LogNamedBytes32 event raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogNamedBytes32 struct {
	Key string
	Val [32]byte
	Raw types.Log // Blockchain specific contextual infos
}

// FilterLogNamedBytes32 is a free log retrieval operation binding the contract event 0xafb795c9c61e4fe7468c386f925d7a5429ecad9c0495ddb8d38d690614d32f99.
//
// Solidity: event log_named_bytes32(string key, bytes32 val)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) FilterLogNamedBytes32(opts *bind.FilterOpts) (*AcrossV3AdapterTestLogNamedBytes32Iterator, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.FilterLogs(opts, "log_named_bytes32")
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestLogNamedBytes32Iterator{contract: _AcrossV3AdapterTest.contract, event: "log_named_bytes32", logs: logs, sub: sub}, nil
}

// WatchLogNamedBytes32 is a free log subscription operation binding the contract event 0xafb795c9c61e4fe7468c386f925d7a5429ecad9c0495ddb8d38d690614d32f99.
//
// Solidity: event log_named_bytes32(string key, bytes32 val)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) WatchLogNamedBytes32(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterTestLogNamedBytes32) (event.Subscription, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.WatchLogs(opts, "log_named_bytes32")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterTestLogNamedBytes32)
				if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_named_bytes32", log); err != nil {
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
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) ParseLogNamedBytes32(log types.Log) (*AcrossV3AdapterTestLogNamedBytes32, error) {
	event := new(AcrossV3AdapterTestLogNamedBytes32)
	if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_named_bytes32", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterTestLogNamedDecimalIntIterator is returned from FilterLogNamedDecimalInt and is used to iterate over the raw logs and unpacked data for LogNamedDecimalInt events raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogNamedDecimalIntIterator struct {
	Event *AcrossV3AdapterTestLogNamedDecimalInt // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterTestLogNamedDecimalIntIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterTestLogNamedDecimalInt)
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
		it.Event = new(AcrossV3AdapterTestLogNamedDecimalInt)
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
func (it *AcrossV3AdapterTestLogNamedDecimalIntIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterTestLogNamedDecimalIntIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterTestLogNamedDecimalInt represents a LogNamedDecimalInt event raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogNamedDecimalInt struct {
	Key      string
	Val      *big.Int
	Decimals *big.Int
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterLogNamedDecimalInt is a free log retrieval operation binding the contract event 0x5da6ce9d51151ba10c09a559ef24d520b9dac5c5b8810ae8434e4d0d86411a95.
//
// Solidity: event log_named_decimal_int(string key, int256 val, uint256 decimals)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) FilterLogNamedDecimalInt(opts *bind.FilterOpts) (*AcrossV3AdapterTestLogNamedDecimalIntIterator, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.FilterLogs(opts, "log_named_decimal_int")
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestLogNamedDecimalIntIterator{contract: _AcrossV3AdapterTest.contract, event: "log_named_decimal_int", logs: logs, sub: sub}, nil
}

// WatchLogNamedDecimalInt is a free log subscription operation binding the contract event 0x5da6ce9d51151ba10c09a559ef24d520b9dac5c5b8810ae8434e4d0d86411a95.
//
// Solidity: event log_named_decimal_int(string key, int256 val, uint256 decimals)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) WatchLogNamedDecimalInt(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterTestLogNamedDecimalInt) (event.Subscription, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.WatchLogs(opts, "log_named_decimal_int")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterTestLogNamedDecimalInt)
				if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_named_decimal_int", log); err != nil {
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
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) ParseLogNamedDecimalInt(log types.Log) (*AcrossV3AdapterTestLogNamedDecimalInt, error) {
	event := new(AcrossV3AdapterTestLogNamedDecimalInt)
	if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_named_decimal_int", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterTestLogNamedDecimalUintIterator is returned from FilterLogNamedDecimalUint and is used to iterate over the raw logs and unpacked data for LogNamedDecimalUint events raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogNamedDecimalUintIterator struct {
	Event *AcrossV3AdapterTestLogNamedDecimalUint // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterTestLogNamedDecimalUintIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterTestLogNamedDecimalUint)
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
		it.Event = new(AcrossV3AdapterTestLogNamedDecimalUint)
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
func (it *AcrossV3AdapterTestLogNamedDecimalUintIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterTestLogNamedDecimalUintIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterTestLogNamedDecimalUint represents a LogNamedDecimalUint event raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogNamedDecimalUint struct {
	Key      string
	Val      *big.Int
	Decimals *big.Int
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterLogNamedDecimalUint is a free log retrieval operation binding the contract event 0xeb8ba43ced7537421946bd43e828b8b2b8428927aa8f801c13d934bf11aca57b.
//
// Solidity: event log_named_decimal_uint(string key, uint256 val, uint256 decimals)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) FilterLogNamedDecimalUint(opts *bind.FilterOpts) (*AcrossV3AdapterTestLogNamedDecimalUintIterator, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.FilterLogs(opts, "log_named_decimal_uint")
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestLogNamedDecimalUintIterator{contract: _AcrossV3AdapterTest.contract, event: "log_named_decimal_uint", logs: logs, sub: sub}, nil
}

// WatchLogNamedDecimalUint is a free log subscription operation binding the contract event 0xeb8ba43ced7537421946bd43e828b8b2b8428927aa8f801c13d934bf11aca57b.
//
// Solidity: event log_named_decimal_uint(string key, uint256 val, uint256 decimals)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) WatchLogNamedDecimalUint(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterTestLogNamedDecimalUint) (event.Subscription, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.WatchLogs(opts, "log_named_decimal_uint")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterTestLogNamedDecimalUint)
				if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_named_decimal_uint", log); err != nil {
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
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) ParseLogNamedDecimalUint(log types.Log) (*AcrossV3AdapterTestLogNamedDecimalUint, error) {
	event := new(AcrossV3AdapterTestLogNamedDecimalUint)
	if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_named_decimal_uint", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterTestLogNamedIntIterator is returned from FilterLogNamedInt and is used to iterate over the raw logs and unpacked data for LogNamedInt events raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogNamedIntIterator struct {
	Event *AcrossV3AdapterTestLogNamedInt // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterTestLogNamedIntIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterTestLogNamedInt)
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
		it.Event = new(AcrossV3AdapterTestLogNamedInt)
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
func (it *AcrossV3AdapterTestLogNamedIntIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterTestLogNamedIntIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterTestLogNamedInt represents a LogNamedInt event raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogNamedInt struct {
	Key string
	Val *big.Int
	Raw types.Log // Blockchain specific contextual infos
}

// FilterLogNamedInt is a free log retrieval operation binding the contract event 0x2fe632779174374378442a8e978bccfbdcc1d6b2b0d81f7e8eb776ab2286f168.
//
// Solidity: event log_named_int(string key, int256 val)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) FilterLogNamedInt(opts *bind.FilterOpts) (*AcrossV3AdapterTestLogNamedIntIterator, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.FilterLogs(opts, "log_named_int")
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestLogNamedIntIterator{contract: _AcrossV3AdapterTest.contract, event: "log_named_int", logs: logs, sub: sub}, nil
}

// WatchLogNamedInt is a free log subscription operation binding the contract event 0x2fe632779174374378442a8e978bccfbdcc1d6b2b0d81f7e8eb776ab2286f168.
//
// Solidity: event log_named_int(string key, int256 val)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) WatchLogNamedInt(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterTestLogNamedInt) (event.Subscription, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.WatchLogs(opts, "log_named_int")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterTestLogNamedInt)
				if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_named_int", log); err != nil {
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
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) ParseLogNamedInt(log types.Log) (*AcrossV3AdapterTestLogNamedInt, error) {
	event := new(AcrossV3AdapterTestLogNamedInt)
	if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_named_int", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterTestLogNamedStringIterator is returned from FilterLogNamedString and is used to iterate over the raw logs and unpacked data for LogNamedString events raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogNamedStringIterator struct {
	Event *AcrossV3AdapterTestLogNamedString // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterTestLogNamedStringIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterTestLogNamedString)
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
		it.Event = new(AcrossV3AdapterTestLogNamedString)
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
func (it *AcrossV3AdapterTestLogNamedStringIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterTestLogNamedStringIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterTestLogNamedString represents a LogNamedString event raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogNamedString struct {
	Key string
	Val string
	Raw types.Log // Blockchain specific contextual infos
}

// FilterLogNamedString is a free log retrieval operation binding the contract event 0x280f4446b28a1372417dda658d30b95b2992b12ac9c7f378535f29a97acf3583.
//
// Solidity: event log_named_string(string key, string val)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) FilterLogNamedString(opts *bind.FilterOpts) (*AcrossV3AdapterTestLogNamedStringIterator, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.FilterLogs(opts, "log_named_string")
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestLogNamedStringIterator{contract: _AcrossV3AdapterTest.contract, event: "log_named_string", logs: logs, sub: sub}, nil
}

// WatchLogNamedString is a free log subscription operation binding the contract event 0x280f4446b28a1372417dda658d30b95b2992b12ac9c7f378535f29a97acf3583.
//
// Solidity: event log_named_string(string key, string val)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) WatchLogNamedString(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterTestLogNamedString) (event.Subscription, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.WatchLogs(opts, "log_named_string")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterTestLogNamedString)
				if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_named_string", log); err != nil {
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
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) ParseLogNamedString(log types.Log) (*AcrossV3AdapterTestLogNamedString, error) {
	event := new(AcrossV3AdapterTestLogNamedString)
	if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_named_string", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterTestLogNamedUintIterator is returned from FilterLogNamedUint and is used to iterate over the raw logs and unpacked data for LogNamedUint events raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogNamedUintIterator struct {
	Event *AcrossV3AdapterTestLogNamedUint // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterTestLogNamedUintIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterTestLogNamedUint)
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
		it.Event = new(AcrossV3AdapterTestLogNamedUint)
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
func (it *AcrossV3AdapterTestLogNamedUintIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterTestLogNamedUintIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterTestLogNamedUint represents a LogNamedUint event raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogNamedUint struct {
	Key string
	Val *big.Int
	Raw types.Log // Blockchain specific contextual infos
}

// FilterLogNamedUint is a free log retrieval operation binding the contract event 0xb2de2fbe801a0df6c0cbddfd448ba3c41d48a040ca35c56c8196ef0fcae721a8.
//
// Solidity: event log_named_uint(string key, uint256 val)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) FilterLogNamedUint(opts *bind.FilterOpts) (*AcrossV3AdapterTestLogNamedUintIterator, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.FilterLogs(opts, "log_named_uint")
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestLogNamedUintIterator{contract: _AcrossV3AdapterTest.contract, event: "log_named_uint", logs: logs, sub: sub}, nil
}

// WatchLogNamedUint is a free log subscription operation binding the contract event 0xb2de2fbe801a0df6c0cbddfd448ba3c41d48a040ca35c56c8196ef0fcae721a8.
//
// Solidity: event log_named_uint(string key, uint256 val)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) WatchLogNamedUint(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterTestLogNamedUint) (event.Subscription, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.WatchLogs(opts, "log_named_uint")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterTestLogNamedUint)
				if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_named_uint", log); err != nil {
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
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) ParseLogNamedUint(log types.Log) (*AcrossV3AdapterTestLogNamedUint, error) {
	event := new(AcrossV3AdapterTestLogNamedUint)
	if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_named_uint", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterTestLogStringIterator is returned from FilterLogString and is used to iterate over the raw logs and unpacked data for LogString events raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogStringIterator struct {
	Event *AcrossV3AdapterTestLogString // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterTestLogStringIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterTestLogString)
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
		it.Event = new(AcrossV3AdapterTestLogString)
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
func (it *AcrossV3AdapterTestLogStringIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterTestLogStringIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterTestLogString represents a LogString event raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogString struct {
	Arg0 string
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterLogString is a free log retrieval operation binding the contract event 0x0b2e13ff20ac7b474198655583edf70dedd2c1dc980e329c4fbb2fc0748b796b.
//
// Solidity: event log_string(string arg0)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) FilterLogString(opts *bind.FilterOpts) (*AcrossV3AdapterTestLogStringIterator, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.FilterLogs(opts, "log_string")
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestLogStringIterator{contract: _AcrossV3AdapterTest.contract, event: "log_string", logs: logs, sub: sub}, nil
}

// WatchLogString is a free log subscription operation binding the contract event 0x0b2e13ff20ac7b474198655583edf70dedd2c1dc980e329c4fbb2fc0748b796b.
//
// Solidity: event log_string(string arg0)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) WatchLogString(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterTestLogString) (event.Subscription, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.WatchLogs(opts, "log_string")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterTestLogString)
				if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_string", log); err != nil {
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
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) ParseLogString(log types.Log) (*AcrossV3AdapterTestLogString, error) {
	event := new(AcrossV3AdapterTestLogString)
	if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_string", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterTestLogUintIterator is returned from FilterLogUint and is used to iterate over the raw logs and unpacked data for LogUint events raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogUintIterator struct {
	Event *AcrossV3AdapterTestLogUint // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterTestLogUintIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterTestLogUint)
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
		it.Event = new(AcrossV3AdapterTestLogUint)
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
func (it *AcrossV3AdapterTestLogUintIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterTestLogUintIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterTestLogUint represents a LogUint event raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogUint struct {
	Arg0 *big.Int
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterLogUint is a free log retrieval operation binding the contract event 0x2cab9790510fd8bdfbd2115288db33fec66691d476efc5427cfd4c0969301755.
//
// Solidity: event log_uint(uint256 arg0)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) FilterLogUint(opts *bind.FilterOpts) (*AcrossV3AdapterTestLogUintIterator, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.FilterLogs(opts, "log_uint")
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestLogUintIterator{contract: _AcrossV3AdapterTest.contract, event: "log_uint", logs: logs, sub: sub}, nil
}

// WatchLogUint is a free log subscription operation binding the contract event 0x2cab9790510fd8bdfbd2115288db33fec66691d476efc5427cfd4c0969301755.
//
// Solidity: event log_uint(uint256 arg0)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) WatchLogUint(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterTestLogUint) (event.Subscription, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.WatchLogs(opts, "log_uint")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterTestLogUint)
				if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_uint", log); err != nil {
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
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) ParseLogUint(log types.Log) (*AcrossV3AdapterTestLogUint, error) {
	event := new(AcrossV3AdapterTestLogUint)
	if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "log_uint", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterTestLogsIterator is returned from FilterLogs and is used to iterate over the raw logs and unpacked data for Logs events raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogsIterator struct {
	Event *AcrossV3AdapterTestLogs // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterTestLogsIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterTestLogs)
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
		it.Event = new(AcrossV3AdapterTestLogs)
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
func (it *AcrossV3AdapterTestLogsIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterTestLogsIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterTestLogs represents a Logs event raised by the AcrossV3AdapterTest contract.
type AcrossV3AdapterTestLogs struct {
	Arg0 []byte
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterLogs is a free log retrieval operation binding the contract event 0xe7950ede0394b9f2ce4a5a1bf5a7e1852411f7e6661b4308c913c4bfd11027e4.
//
// Solidity: event logs(bytes arg0)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) FilterLogs(opts *bind.FilterOpts) (*AcrossV3AdapterTestLogsIterator, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.FilterLogs(opts, "logs")
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTestLogsIterator{contract: _AcrossV3AdapterTest.contract, event: "logs", logs: logs, sub: sub}, nil
}

// WatchLogs is a free log subscription operation binding the contract event 0xe7950ede0394b9f2ce4a5a1bf5a7e1852411f7e6661b4308c913c4bfd11027e4.
//
// Solidity: event logs(bytes arg0)
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) WatchLogs(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterTestLogs) (event.Subscription, error) {

	logs, sub, err := _AcrossV3AdapterTest.contract.WatchLogs(opts, "logs")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterTestLogs)
				if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "logs", log); err != nil {
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
func (_AcrossV3AdapterTest *AcrossV3AdapterTestFilterer) ParseLogs(log types.Log) (*AcrossV3AdapterTestLogs, error) {
	event := new(AcrossV3AdapterTestLogs)
	if err := _AcrossV3AdapterTest.contract.UnpackLog(event, "logs", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
