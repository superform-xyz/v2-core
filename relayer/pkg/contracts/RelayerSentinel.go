// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package contracts

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

// RelayerSentinelMetaData contains all meta data concerning the RelayerSentinel contract.
var RelayerSentinelMetaData = &bind.MetaData{
	ABI: "[{\"inputs\":[{\"internalType\":\"address\",\"name\":\"registry_\",\"type\":\"address\"}],\"stateMutability\":\"nonpayable\",\"type\":\"constructor\"},{\"inputs\":[],\"name\":\"ADDRESS_NOT_VALID\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"BLOCK_CHAIN_ID_OUT_OF_BOUNDS\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"CALL_FAILED\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"INVALID_HOOK\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"INVALID_LENGTH\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"INVALID_SUPER_REGISTRY\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"NOTIFIER_NOT_ALLOWED\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"NOT_RELAYER\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"NOT_RELAYER_MANAGER\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"NOT_WHITELISTED\",\"type\":\"error\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"decoder\",\"type\":\"address\"}],\"name\":\"DecoderRemovedFromWhitelist\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"decoder\",\"type\":\"address\"}],\"name\":\"DecoderWhitelisted\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"module\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"enumIRelayerSentinel.ModuleNotificationType\",\"name\":\"notificationType\",\"type\":\"uint8\"}],\"name\":\"ModuleNotificationTypeSet\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"module\",\"type\":\"address\"}],\"name\":\"ModuleRemovedFromWhitelist\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"module\",\"type\":\"address\"}],\"name\":\"ModuleWhitelisted\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint64\",\"name\":\"destinationChainId\",\"type\":\"uint64\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"destinationContract\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"bytes\",\"name\":\"data\",\"type\":\"bytes\"}],\"name\":\"Msg\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"superRegistry\",\"type\":\"address\"}],\"name\":\"SuperRegistrySet\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"hook\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"bool\",\"name\":\"allowed\",\"type\":\"bool\"}],\"name\":\"WhitelistedHook\",\"type\":\"event\"},{\"inputs\":[],\"name\":\"CHAIN_ID\",\"outputs\":[{\"internalType\":\"uint64\",\"name\":\"\",\"type\":\"uint64\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"decoder_\",\"type\":\"address\"}],\"name\":\"addDecoderToWhitelist\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"module_\",\"type\":\"address\"}],\"name\":\"addModuleToWhitelist\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"name\":\"decoderWhitelist\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"name\":\"moduleWhitelist\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"decoder_\",\"type\":\"address\"},{\"internalType\":\"bytes\",\"name\":\"data_\",\"type\":\"bytes\"},{\"internalType\":\"bool\",\"name\":\"success_\",\"type\":\"bool\"}],\"name\":\"notify\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"target\",\"type\":\"address\"},{\"internalType\":\"bytes\",\"name\":\"data\",\"type\":\"bytes\"}],\"name\":\"receiveRelayerData\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"decoder_\",\"type\":\"address\"}],\"name\":\"removeDecoderFromWhitelist\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"module_\",\"type\":\"address\"}],\"name\":\"removeModuleFromWhitelist\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"superRegistry\",\"outputs\":[{\"internalType\":\"contractISuperRegistry\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"}]",
	Bin: "0x608060405234801561000f575f5ffd5b50604051611d1d380380611d1d833981810160405281019061003191906101a5565b5f73ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff1603610096576040517f0f58648f00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b67ffffffffffffffff80164611156100da576040517f7ecdf93300000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b465f60146101000a81548167ffffffffffffffff021916908367ffffffffffffffff160217905550805f5f6101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff160217905550506101d0565b5f5ffd5b5f73ffffffffffffffffffffffffffffffffffffffff82169050919050565b5f6101748261014b565b9050919050565b6101848161016a565b811461018e575f5ffd5b50565b5f8151905061019f8161017b565b92915050565b5f602082840312156101ba576101b9610147565b5b5f6101c784828501610191565b91505092915050565b611b40806101dd5f395ff3fe608060405234801561000f575f5ffd5b506004361061009c575f3560e01c8063be5e8eef11610064578063be5e8eef14610144578063c500559114610160578063d1dfb1741461017c578063d363f690146101ac578063fc04cc86146101c85761009c565b806324c73dda146100a057806385e1f4d0146100be5780638747eb68146100dc5780638bd695b8146100f8578063ae85733b14610114575b5f5ffd5b6100a86101e4565b6040516100b59190611471565b60405180910390f35b6100c6610208565b6040516100d391906114ac565b60405180910390f35b6100f660048036038101906100f19190611511565b610221565b005b610112600480360381019061010d9190611678565b610564565b005b61012e60048036038101906101299190611511565b610790565b60405161013b91906116ec565b60405180910390f35b61015e60048036038101906101599190611511565b6107ad565b005b61017a6004803603810190610175919061178c565b610af0565b005b61019660048036038101906101919190611511565b610b02565b6040516101a391906116ec565b60405180910390f35b6101c660048036038101906101c19190611511565b610b1f565b005b6101e260048036038101906101dd9190611511565b610e62565b005b5f5f9054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b5f60149054906101000a900467ffffffffffffffff1681565b5f5f5f9054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff166321f8a7215f5f9054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff166322bb000a6040518163ffffffff1660e01b8152600401602060405180830381865afa1580156102c7573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906102eb9190611830565b6040518263ffffffff1660e01b8152600401610307919061186a565b602060405180830381865afa158015610322573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906103469190611897565b90508073ffffffffffffffffffffffffffffffffffffffff1663ac4ab3fb338373ffffffffffffffffffffffffffffffffffffffff16636553d5d96040518163ffffffff1660e01b8152600401602060405180830381865afa1580156103ae573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906103d29190611830565b6040518363ffffffff1660e01b81526004016103ef9291906118d1565b602060405180830381865afa15801561040a573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061042e919061190c565b610464576040517f2f74888700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f73ffffffffffffffffffffffffffffffffffffffff168273ffffffffffffffffffffffffffffffffffffffff16036104c9576040517f0f58648f00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f60015f8473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020015f205f6101000a81548160ff0219169083151502179055508173ffffffffffffffffffffffffffffffffffffffff167fdc8d9026956e02a28f815d234adc27127f54ef34d8c43ebb214f52791f5df22260405160405180910390a25050565b5f5f9054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff166321f8a7215f5f9054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1663b8fadeba6040518163ffffffff1660e01b8152600401602060405180830381865afa158015610609573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061062d9190611830565b6040518263ffffffff1660e01b8152600401610649919061186a565b602060405180830381865afa158015610664573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906106889190611897565b73ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff16146106ec576040517f5587823e00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f8273ffffffffffffffffffffffffffffffffffffffff16826040516107129190611989565b5f604051808303815f865af19150503d805f811461074b576040519150601f19603f3d011682016040523d82523d5f602084013e610750565b606091505b505090508061078b576040517f84aed38d00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b505050565b6002602052805f5260405f205f915054906101000a900460ff1681565b5f5f5f9054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff166321f8a7215f5f9054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff166322bb000a6040518163ffffffff1660e01b8152600401602060405180830381865afa158015610853573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906108779190611830565b6040518263ffffffff1660e01b8152600401610893919061186a565b602060405180830381865afa1580156108ae573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906108d29190611897565b90508073ffffffffffffffffffffffffffffffffffffffff1663ac4ab3fb338373ffffffffffffffffffffffffffffffffffffffff16636553d5d96040518163ffffffff1660e01b8152600401602060405180830381865afa15801561093a573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061095e9190611830565b6040518363ffffffff1660e01b815260040161097b9291906118d1565b602060405180830381865afa158015610996573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906109ba919061190c565b6109f0576040517f2f74888700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f73ffffffffffffffffffffffffffffffffffffffff168273ffffffffffffffffffffffffffffffffffffffff1603610a55576040517f0f58648f00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6001805f8473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020015f205f6101000a81548160ff0219169083151502179055508173ffffffffffffffffffffffffffffffffffffffff167f90f779357fcf87c39478bf2115b821d2e9da213cb9af571dea122fd5cae0658960405160405180910390a25050565b610afc848484846111a6565b50505050565b6001602052805f5260405f205f915054906101000a900460ff1681565b5f5f5f9054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff166321f8a7215f5f9054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff166322bb000a6040518163ffffffff1660e01b8152600401602060405180830381865afa158015610bc5573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610be99190611830565b6040518263ffffffff1660e01b8152600401610c05919061186a565b602060405180830381865afa158015610c20573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610c449190611897565b90508073ffffffffffffffffffffffffffffffffffffffff1663ac4ab3fb338373ffffffffffffffffffffffffffffffffffffffff16636553d5d96040518163ffffffff1660e01b8152600401602060405180830381865afa158015610cac573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610cd09190611830565b6040518363ffffffff1660e01b8152600401610ced9291906118d1565b602060405180830381865afa158015610d08573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610d2c919061190c565b610d62576040517f2f74888700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f73ffffffffffffffffffffffffffffffffffffffff168273ffffffffffffffffffffffffffffffffffffffff1603610dc7576040517f0f58648f00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f60025f8473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020015f205f6101000a81548160ff0219169083151502179055508173ffffffffffffffffffffffffffffffffffffffff167fcc6feb9c4a950037d0ebabdc282627c1574abfedbc12b6a11fc324dd23d3f14560405160405180910390a25050565b5f5f5f9054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff166321f8a7215f5f9054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff166322bb000a6040518163ffffffff1660e01b8152600401602060405180830381865afa158015610f08573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610f2c9190611830565b6040518263ffffffff1660e01b8152600401610f48919061186a565b602060405180830381865afa158015610f63573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610f879190611897565b90508073ffffffffffffffffffffffffffffffffffffffff1663ac4ab3fb338373ffffffffffffffffffffffffffffffffffffffff16636553d5d96040518163ffffffff1660e01b8152600401602060405180830381865afa158015610fef573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906110139190611830565b6040518363ffffffff1660e01b81526004016110309291906118d1565b602060405180830381865afa15801561104b573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061106f919061190c565b6110a5576040517f2f74888700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f73ffffffffffffffffffffffffffffffffffffffff168273ffffffffffffffffffffffffffffffffffffffff160361110a576040517f0f58648f00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b600160025f8473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020015f205f6101000a81548160ff0219169083151502179055508173ffffffffffffffffffffffffffffffffffffffff167fb652e1c35eca29bf9ca732fa57b25baa999953139f10e0a376e4685c58e8aca560405160405180910390a25050565b806111dd576040517f84aed38d00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60025f3373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020015f205f9054906101000a900460ff1661125d576040517fbffbc6be00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60015f8573ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020015f205f9054906101000a900460ff166112dd576040517fbffbc6be00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f8473ffffffffffffffffffffffffffffffffffffffff1663a273d5d785856040518363ffffffff1660e01b81526004016113199291906119db565b5f60405180830381865afa158015611333573d5f5f3e3d5ffd5b505050506040513d5f823e3d601f19601f8201168201806040525081019061135b9190611a6b565b90505f5f5f9054906101000a900473ffffffffffffffffffffffffffffffffffffffff1690503373ffffffffffffffffffffffffffffffffffffffff165f60149054906101000a900467ffffffffffffffff1667ffffffffffffffff167f40d10bc6210625f540a70c1e761d4707547eeee98ada8431ff6b91556bbb9a6e846040516113e79190611aea565b60405180910390a3505050505050565b5f73ffffffffffffffffffffffffffffffffffffffff82169050919050565b5f819050919050565b5f61143961143461142f846113f7565b611416565b6113f7565b9050919050565b5f61144a8261141f565b9050919050565b5f61145b82611440565b9050919050565b61146b81611451565b82525050565b5f6020820190506114845f830184611462565b92915050565b5f67ffffffffffffffff82169050919050565b6114a68161148a565b82525050565b5f6020820190506114bf5f83018461149d565b92915050565b5f604051905090565b5f5ffd5b5f5ffd5b5f6114e0826113f7565b9050919050565b6114f0816114d6565b81146114fa575f5ffd5b50565b5f8135905061150b816114e7565b92915050565b5f60208284031215611526576115256114ce565b5b5f611533848285016114fd565b91505092915050565b5f5ffd5b5f5ffd5b5f601f19601f8301169050919050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b61158a82611544565b810181811067ffffffffffffffff821117156115a9576115a8611554565b5b80604052505050565b5f6115bb6114c5565b90506115c78282611581565b919050565b5f67ffffffffffffffff8211156115e6576115e5611554565b5b6115ef82611544565b9050602081019050919050565b828183375f83830152505050565b5f61161c611617846115cc565b6115b2565b90508281526020810184848401111561163857611637611540565b5b6116438482856115fc565b509392505050565b5f82601f83011261165f5761165e61153c565b5b813561166f84826020860161160a565b91505092915050565b5f5f6040838503121561168e5761168d6114ce565b5b5f61169b858286016114fd565b925050602083013567ffffffffffffffff8111156116bc576116bb6114d2565b5b6116c88582860161164b565b9150509250929050565b5f8115159050919050565b6116e6816116d2565b82525050565b5f6020820190506116ff5f8301846116dd565b92915050565b5f5ffd5b5f5ffd5b5f5f83601f8401126117225761172161153c565b5b8235905067ffffffffffffffff81111561173f5761173e611705565b5b60208301915083600182028301111561175b5761175a611709565b5b9250929050565b61176b816116d2565b8114611775575f5ffd5b50565b5f8135905061178681611762565b92915050565b5f5f5f5f606085870312156117a4576117a36114ce565b5b5f6117b1878288016114fd565b945050602085013567ffffffffffffffff8111156117d2576117d16114d2565b5b6117de8782880161170d565b935093505060406117f187828801611778565b91505092959194509250565b5f819050919050565b61180f816117fd565b8114611819575f5ffd5b50565b5f8151905061182a81611806565b92915050565b5f60208284031215611845576118446114ce565b5b5f6118528482850161181c565b91505092915050565b611864816117fd565b82525050565b5f60208201905061187d5f83018461185b565b92915050565b5f81519050611891816114e7565b92915050565b5f602082840312156118ac576118ab6114ce565b5b5f6118b984828501611883565b91505092915050565b6118cb816114d6565b82525050565b5f6040820190506118e45f8301856118c2565b6118f1602083018461185b565b9392505050565b5f8151905061190681611762565b92915050565b5f60208284031215611921576119206114ce565b5b5f61192e848285016118f8565b91505092915050565b5f81519050919050565b5f81905092915050565b8281835e5f83830152505050565b5f61196382611937565b61196d8185611941565b935061197d81856020860161194b565b80840191505092915050565b5f6119948284611959565b915081905092915050565b5f82825260208201905092915050565b5f6119ba838561199f565b93506119c78385846115fc565b6119d083611544565b840190509392505050565b5f6020820190508181035f8301526119f48184866119af565b90509392505050565b5f611a0f611a0a846115cc565b6115b2565b905082815260208101848484011115611a2b57611a2a611540565b5b611a3684828561194b565b509392505050565b5f82601f830112611a5257611a5161153c565b5b8151611a628482602086016119fd565b91505092915050565b5f60208284031215611a8057611a7f6114ce565b5b5f82015167ffffffffffffffff811115611a9d57611a9c6114d2565b5b611aa984828501611a3e565b91505092915050565b5f611abc82611937565b611ac6818561199f565b9350611ad681856020860161194b565b611adf81611544565b840191505092915050565b5f6020820190508181035f830152611b028184611ab2565b90509291505056fea2646970667358221220fd985d04b483cf91109f5229297c29d23b9aec531d9b7741def98f6222df13d764736f6c634300081c0033",
}

// RelayerSentinelABI is the input ABI used to generate the binding from.
// Deprecated: Use RelayerSentinelMetaData.ABI instead.
var RelayerSentinelABI = RelayerSentinelMetaData.ABI

// RelayerSentinelBin is the compiled bytecode used for deploying new contracts.
// Deprecated: Use RelayerSentinelMetaData.Bin instead.
var RelayerSentinelBin = RelayerSentinelMetaData.Bin

// DeployRelayerSentinel deploys a new Ethereum contract, binding an instance of RelayerSentinel to it.
func DeployRelayerSentinel(auth *bind.TransactOpts, backend bind.ContractBackend, registry_ common.Address) (common.Address, *types.Transaction, *RelayerSentinel, error) {
	parsed, err := RelayerSentinelMetaData.GetAbi()
	if err != nil {
		return common.Address{}, nil, nil, err
	}
	if parsed == nil {
		return common.Address{}, nil, nil, errors.New("GetABI returned nil")
	}

	address, tx, contract, err := bind.DeployContract(auth, *parsed, common.FromHex(RelayerSentinelBin), backend, registry_)
	if err != nil {
		return common.Address{}, nil, nil, err
	}
	return address, tx, &RelayerSentinel{RelayerSentinelCaller: RelayerSentinelCaller{contract: contract}, RelayerSentinelTransactor: RelayerSentinelTransactor{contract: contract}, RelayerSentinelFilterer: RelayerSentinelFilterer{contract: contract}}, nil
}

// RelayerSentinel is an auto generated Go binding around an Ethereum contract.
type RelayerSentinel struct {
	RelayerSentinelCaller     // Read-only binding to the contract
	RelayerSentinelTransactor // Write-only binding to the contract
	RelayerSentinelFilterer   // Log filterer for contract events
}

// RelayerSentinelCaller is an auto generated read-only Go binding around an Ethereum contract.
type RelayerSentinelCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// RelayerSentinelTransactor is an auto generated write-only Go binding around an Ethereum contract.
type RelayerSentinelTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// RelayerSentinelFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type RelayerSentinelFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// RelayerSentinelSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type RelayerSentinelSession struct {
	Contract     *RelayerSentinel  // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// RelayerSentinelCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type RelayerSentinelCallerSession struct {
	Contract *RelayerSentinelCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts          // Call options to use throughout this session
}

// RelayerSentinelTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type RelayerSentinelTransactorSession struct {
	Contract     *RelayerSentinelTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts          // Transaction auth options to use throughout this session
}

// RelayerSentinelRaw is an auto generated low-level Go binding around an Ethereum contract.
type RelayerSentinelRaw struct {
	Contract *RelayerSentinel // Generic contract binding to access the raw methods on
}

// RelayerSentinelCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type RelayerSentinelCallerRaw struct {
	Contract *RelayerSentinelCaller // Generic read-only contract binding to access the raw methods on
}

// RelayerSentinelTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type RelayerSentinelTransactorRaw struct {
	Contract *RelayerSentinelTransactor // Generic write-only contract binding to access the raw methods on
}

// NewRelayerSentinel creates a new instance of RelayerSentinel, bound to a specific deployed contract.
func NewRelayerSentinel(address common.Address, backend bind.ContractBackend) (*RelayerSentinel, error) {
	contract, err := bindRelayerSentinel(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &RelayerSentinel{RelayerSentinelCaller: RelayerSentinelCaller{contract: contract}, RelayerSentinelTransactor: RelayerSentinelTransactor{contract: contract}, RelayerSentinelFilterer: RelayerSentinelFilterer{contract: contract}}, nil
}

// NewRelayerSentinelCaller creates a new read-only instance of RelayerSentinel, bound to a specific deployed contract.
func NewRelayerSentinelCaller(address common.Address, caller bind.ContractCaller) (*RelayerSentinelCaller, error) {
	contract, err := bindRelayerSentinel(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &RelayerSentinelCaller{contract: contract}, nil
}

// NewRelayerSentinelTransactor creates a new write-only instance of RelayerSentinel, bound to a specific deployed contract.
func NewRelayerSentinelTransactor(address common.Address, transactor bind.ContractTransactor) (*RelayerSentinelTransactor, error) {
	contract, err := bindRelayerSentinel(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &RelayerSentinelTransactor{contract: contract}, nil
}

// NewRelayerSentinelFilterer creates a new log filterer instance of RelayerSentinel, bound to a specific deployed contract.
func NewRelayerSentinelFilterer(address common.Address, filterer bind.ContractFilterer) (*RelayerSentinelFilterer, error) {
	contract, err := bindRelayerSentinel(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &RelayerSentinelFilterer{contract: contract}, nil
}

// bindRelayerSentinel binds a generic wrapper to an already deployed contract.
func bindRelayerSentinel(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := RelayerSentinelMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_RelayerSentinel *RelayerSentinelRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _RelayerSentinel.Contract.RelayerSentinelCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_RelayerSentinel *RelayerSentinelRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _RelayerSentinel.Contract.RelayerSentinelTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_RelayerSentinel *RelayerSentinelRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _RelayerSentinel.Contract.RelayerSentinelTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_RelayerSentinel *RelayerSentinelCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _RelayerSentinel.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_RelayerSentinel *RelayerSentinelTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _RelayerSentinel.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_RelayerSentinel *RelayerSentinelTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _RelayerSentinel.Contract.contract.Transact(opts, method, params...)
}

// CHAINID is a free data retrieval call binding the contract method 0x85e1f4d0.
//
// Solidity: function CHAIN_ID() view returns(uint64)
func (_RelayerSentinel *RelayerSentinelCaller) CHAINID(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _RelayerSentinel.contract.Call(opts, &out, "CHAIN_ID")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// CHAINID is a free data retrieval call binding the contract method 0x85e1f4d0.
//
// Solidity: function CHAIN_ID() view returns(uint64)
func (_RelayerSentinel *RelayerSentinelSession) CHAINID() (uint64, error) {
	return _RelayerSentinel.Contract.CHAINID(&_RelayerSentinel.CallOpts)
}

// CHAINID is a free data retrieval call binding the contract method 0x85e1f4d0.
//
// Solidity: function CHAIN_ID() view returns(uint64)
func (_RelayerSentinel *RelayerSentinelCallerSession) CHAINID() (uint64, error) {
	return _RelayerSentinel.Contract.CHAINID(&_RelayerSentinel.CallOpts)
}

// DecoderWhitelist is a free data retrieval call binding the contract method 0xd1dfb174.
//
// Solidity: function decoderWhitelist(address ) view returns(bool)
func (_RelayerSentinel *RelayerSentinelCaller) DecoderWhitelist(opts *bind.CallOpts, arg0 common.Address) (bool, error) {
	var out []interface{}
	err := _RelayerSentinel.contract.Call(opts, &out, "decoderWhitelist", arg0)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// DecoderWhitelist is a free data retrieval call binding the contract method 0xd1dfb174.
//
// Solidity: function decoderWhitelist(address ) view returns(bool)
func (_RelayerSentinel *RelayerSentinelSession) DecoderWhitelist(arg0 common.Address) (bool, error) {
	return _RelayerSentinel.Contract.DecoderWhitelist(&_RelayerSentinel.CallOpts, arg0)
}

// DecoderWhitelist is a free data retrieval call binding the contract method 0xd1dfb174.
//
// Solidity: function decoderWhitelist(address ) view returns(bool)
func (_RelayerSentinel *RelayerSentinelCallerSession) DecoderWhitelist(arg0 common.Address) (bool, error) {
	return _RelayerSentinel.Contract.DecoderWhitelist(&_RelayerSentinel.CallOpts, arg0)
}

// ModuleWhitelist is a free data retrieval call binding the contract method 0xae85733b.
//
// Solidity: function moduleWhitelist(address ) view returns(bool)
func (_RelayerSentinel *RelayerSentinelCaller) ModuleWhitelist(opts *bind.CallOpts, arg0 common.Address) (bool, error) {
	var out []interface{}
	err := _RelayerSentinel.contract.Call(opts, &out, "moduleWhitelist", arg0)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// ModuleWhitelist is a free data retrieval call binding the contract method 0xae85733b.
//
// Solidity: function moduleWhitelist(address ) view returns(bool)
func (_RelayerSentinel *RelayerSentinelSession) ModuleWhitelist(arg0 common.Address) (bool, error) {
	return _RelayerSentinel.Contract.ModuleWhitelist(&_RelayerSentinel.CallOpts, arg0)
}

// ModuleWhitelist is a free data retrieval call binding the contract method 0xae85733b.
//
// Solidity: function moduleWhitelist(address ) view returns(bool)
func (_RelayerSentinel *RelayerSentinelCallerSession) ModuleWhitelist(arg0 common.Address) (bool, error) {
	return _RelayerSentinel.Contract.ModuleWhitelist(&_RelayerSentinel.CallOpts, arg0)
}

// SuperRegistry is a free data retrieval call binding the contract method 0x24c73dda.
//
// Solidity: function superRegistry() view returns(address)
func (_RelayerSentinel *RelayerSentinelCaller) SuperRegistry(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _RelayerSentinel.contract.Call(opts, &out, "superRegistry")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SuperRegistry is a free data retrieval call binding the contract method 0x24c73dda.
//
// Solidity: function superRegistry() view returns(address)
func (_RelayerSentinel *RelayerSentinelSession) SuperRegistry() (common.Address, error) {
	return _RelayerSentinel.Contract.SuperRegistry(&_RelayerSentinel.CallOpts)
}

// SuperRegistry is a free data retrieval call binding the contract method 0x24c73dda.
//
// Solidity: function superRegistry() view returns(address)
func (_RelayerSentinel *RelayerSentinelCallerSession) SuperRegistry() (common.Address, error) {
	return _RelayerSentinel.Contract.SuperRegistry(&_RelayerSentinel.CallOpts)
}

// AddDecoderToWhitelist is a paid mutator transaction binding the contract method 0xbe5e8eef.
//
// Solidity: function addDecoderToWhitelist(address decoder_) returns()
func (_RelayerSentinel *RelayerSentinelTransactor) AddDecoderToWhitelist(opts *bind.TransactOpts, decoder_ common.Address) (*types.Transaction, error) {
	return _RelayerSentinel.contract.Transact(opts, "addDecoderToWhitelist", decoder_)
}

// AddDecoderToWhitelist is a paid mutator transaction binding the contract method 0xbe5e8eef.
//
// Solidity: function addDecoderToWhitelist(address decoder_) returns()
func (_RelayerSentinel *RelayerSentinelSession) AddDecoderToWhitelist(decoder_ common.Address) (*types.Transaction, error) {
	return _RelayerSentinel.Contract.AddDecoderToWhitelist(&_RelayerSentinel.TransactOpts, decoder_)
}

// AddDecoderToWhitelist is a paid mutator transaction binding the contract method 0xbe5e8eef.
//
// Solidity: function addDecoderToWhitelist(address decoder_) returns()
func (_RelayerSentinel *RelayerSentinelTransactorSession) AddDecoderToWhitelist(decoder_ common.Address) (*types.Transaction, error) {
	return _RelayerSentinel.Contract.AddDecoderToWhitelist(&_RelayerSentinel.TransactOpts, decoder_)
}

// AddModuleToWhitelist is a paid mutator transaction binding the contract method 0xfc04cc86.
//
// Solidity: function addModuleToWhitelist(address module_) returns()
func (_RelayerSentinel *RelayerSentinelTransactor) AddModuleToWhitelist(opts *bind.TransactOpts, module_ common.Address) (*types.Transaction, error) {
	return _RelayerSentinel.contract.Transact(opts, "addModuleToWhitelist", module_)
}

// AddModuleToWhitelist is a paid mutator transaction binding the contract method 0xfc04cc86.
//
// Solidity: function addModuleToWhitelist(address module_) returns()
func (_RelayerSentinel *RelayerSentinelSession) AddModuleToWhitelist(module_ common.Address) (*types.Transaction, error) {
	return _RelayerSentinel.Contract.AddModuleToWhitelist(&_RelayerSentinel.TransactOpts, module_)
}

// AddModuleToWhitelist is a paid mutator transaction binding the contract method 0xfc04cc86.
//
// Solidity: function addModuleToWhitelist(address module_) returns()
func (_RelayerSentinel *RelayerSentinelTransactorSession) AddModuleToWhitelist(module_ common.Address) (*types.Transaction, error) {
	return _RelayerSentinel.Contract.AddModuleToWhitelist(&_RelayerSentinel.TransactOpts, module_)
}

// Notify is a paid mutator transaction binding the contract method 0xc5005591.
//
// Solidity: function notify(address decoder_, bytes data_, bool success_) returns()
func (_RelayerSentinel *RelayerSentinelTransactor) Notify(opts *bind.TransactOpts, decoder_ common.Address, data_ []byte, success_ bool) (*types.Transaction, error) {
	return _RelayerSentinel.contract.Transact(opts, "notify", decoder_, data_, success_)
}

// Notify is a paid mutator transaction binding the contract method 0xc5005591.
//
// Solidity: function notify(address decoder_, bytes data_, bool success_) returns()
func (_RelayerSentinel *RelayerSentinelSession) Notify(decoder_ common.Address, data_ []byte, success_ bool) (*types.Transaction, error) {
	return _RelayerSentinel.Contract.Notify(&_RelayerSentinel.TransactOpts, decoder_, data_, success_)
}

// Notify is a paid mutator transaction binding the contract method 0xc5005591.
//
// Solidity: function notify(address decoder_, bytes data_, bool success_) returns()
func (_RelayerSentinel *RelayerSentinelTransactorSession) Notify(decoder_ common.Address, data_ []byte, success_ bool) (*types.Transaction, error) {
	return _RelayerSentinel.Contract.Notify(&_RelayerSentinel.TransactOpts, decoder_, data_, success_)
}

// ReceiveRelayerData is a paid mutator transaction binding the contract method 0x8bd695b8.
//
// Solidity: function receiveRelayerData(address target, bytes data) returns()
func (_RelayerSentinel *RelayerSentinelTransactor) ReceiveRelayerData(opts *bind.TransactOpts, target common.Address, data []byte) (*types.Transaction, error) {
	return _RelayerSentinel.contract.Transact(opts, "receiveRelayerData", target, data)
}

// ReceiveRelayerData is a paid mutator transaction binding the contract method 0x8bd695b8.
//
// Solidity: function receiveRelayerData(address target, bytes data) returns()
func (_RelayerSentinel *RelayerSentinelSession) ReceiveRelayerData(target common.Address, data []byte) (*types.Transaction, error) {
	return _RelayerSentinel.Contract.ReceiveRelayerData(&_RelayerSentinel.TransactOpts, target, data)
}

// ReceiveRelayerData is a paid mutator transaction binding the contract method 0x8bd695b8.
//
// Solidity: function receiveRelayerData(address target, bytes data) returns()
func (_RelayerSentinel *RelayerSentinelTransactorSession) ReceiveRelayerData(target common.Address, data []byte) (*types.Transaction, error) {
	return _RelayerSentinel.Contract.ReceiveRelayerData(&_RelayerSentinel.TransactOpts, target, data)
}

// RemoveDecoderFromWhitelist is a paid mutator transaction binding the contract method 0x8747eb68.
//
// Solidity: function removeDecoderFromWhitelist(address decoder_) returns()
func (_RelayerSentinel *RelayerSentinelTransactor) RemoveDecoderFromWhitelist(opts *bind.TransactOpts, decoder_ common.Address) (*types.Transaction, error) {
	return _RelayerSentinel.contract.Transact(opts, "removeDecoderFromWhitelist", decoder_)
}

// RemoveDecoderFromWhitelist is a paid mutator transaction binding the contract method 0x8747eb68.
//
// Solidity: function removeDecoderFromWhitelist(address decoder_) returns()
func (_RelayerSentinel *RelayerSentinelSession) RemoveDecoderFromWhitelist(decoder_ common.Address) (*types.Transaction, error) {
	return _RelayerSentinel.Contract.RemoveDecoderFromWhitelist(&_RelayerSentinel.TransactOpts, decoder_)
}

// RemoveDecoderFromWhitelist is a paid mutator transaction binding the contract method 0x8747eb68.
//
// Solidity: function removeDecoderFromWhitelist(address decoder_) returns()
func (_RelayerSentinel *RelayerSentinelTransactorSession) RemoveDecoderFromWhitelist(decoder_ common.Address) (*types.Transaction, error) {
	return _RelayerSentinel.Contract.RemoveDecoderFromWhitelist(&_RelayerSentinel.TransactOpts, decoder_)
}

// RemoveModuleFromWhitelist is a paid mutator transaction binding the contract method 0xd363f690.
//
// Solidity: function removeModuleFromWhitelist(address module_) returns()
func (_RelayerSentinel *RelayerSentinelTransactor) RemoveModuleFromWhitelist(opts *bind.TransactOpts, module_ common.Address) (*types.Transaction, error) {
	return _RelayerSentinel.contract.Transact(opts, "removeModuleFromWhitelist", module_)
}

// RemoveModuleFromWhitelist is a paid mutator transaction binding the contract method 0xd363f690.
//
// Solidity: function removeModuleFromWhitelist(address module_) returns()
func (_RelayerSentinel *RelayerSentinelSession) RemoveModuleFromWhitelist(module_ common.Address) (*types.Transaction, error) {
	return _RelayerSentinel.Contract.RemoveModuleFromWhitelist(&_RelayerSentinel.TransactOpts, module_)
}

// RemoveModuleFromWhitelist is a paid mutator transaction binding the contract method 0xd363f690.
//
// Solidity: function removeModuleFromWhitelist(address module_) returns()
func (_RelayerSentinel *RelayerSentinelTransactorSession) RemoveModuleFromWhitelist(module_ common.Address) (*types.Transaction, error) {
	return _RelayerSentinel.Contract.RemoveModuleFromWhitelist(&_RelayerSentinel.TransactOpts, module_)
}

// RelayerSentinelDecoderRemovedFromWhitelistIterator is returned from FilterDecoderRemovedFromWhitelist and is used to iterate over the raw logs and unpacked data for DecoderRemovedFromWhitelist events raised by the RelayerSentinel contract.
type RelayerSentinelDecoderRemovedFromWhitelistIterator struct {
	Event *RelayerSentinelDecoderRemovedFromWhitelist // Event containing the contract specifics and raw log

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
func (it *RelayerSentinelDecoderRemovedFromWhitelistIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RelayerSentinelDecoderRemovedFromWhitelist)
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
		it.Event = new(RelayerSentinelDecoderRemovedFromWhitelist)
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
func (it *RelayerSentinelDecoderRemovedFromWhitelistIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RelayerSentinelDecoderRemovedFromWhitelistIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RelayerSentinelDecoderRemovedFromWhitelist represents a DecoderRemovedFromWhitelist event raised by the RelayerSentinel contract.
type RelayerSentinelDecoderRemovedFromWhitelist struct {
	Decoder common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterDecoderRemovedFromWhitelist is a free log retrieval operation binding the contract event 0xdc8d9026956e02a28f815d234adc27127f54ef34d8c43ebb214f52791f5df222.
//
// Solidity: event DecoderRemovedFromWhitelist(address indexed decoder)
func (_RelayerSentinel *RelayerSentinelFilterer) FilterDecoderRemovedFromWhitelist(opts *bind.FilterOpts, decoder []common.Address) (*RelayerSentinelDecoderRemovedFromWhitelistIterator, error) {

	var decoderRule []interface{}
	for _, decoderItem := range decoder {
		decoderRule = append(decoderRule, decoderItem)
	}

	logs, sub, err := _RelayerSentinel.contract.FilterLogs(opts, "DecoderRemovedFromWhitelist", decoderRule)
	if err != nil {
		return nil, err
	}
	return &RelayerSentinelDecoderRemovedFromWhitelistIterator{contract: _RelayerSentinel.contract, event: "DecoderRemovedFromWhitelist", logs: logs, sub: sub}, nil
}

// WatchDecoderRemovedFromWhitelist is a free log subscription operation binding the contract event 0xdc8d9026956e02a28f815d234adc27127f54ef34d8c43ebb214f52791f5df222.
//
// Solidity: event DecoderRemovedFromWhitelist(address indexed decoder)
func (_RelayerSentinel *RelayerSentinelFilterer) WatchDecoderRemovedFromWhitelist(opts *bind.WatchOpts, sink chan<- *RelayerSentinelDecoderRemovedFromWhitelist, decoder []common.Address) (event.Subscription, error) {

	var decoderRule []interface{}
	for _, decoderItem := range decoder {
		decoderRule = append(decoderRule, decoderItem)
	}

	logs, sub, err := _RelayerSentinel.contract.WatchLogs(opts, "DecoderRemovedFromWhitelist", decoderRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RelayerSentinelDecoderRemovedFromWhitelist)
				if err := _RelayerSentinel.contract.UnpackLog(event, "DecoderRemovedFromWhitelist", log); err != nil {
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

// ParseDecoderRemovedFromWhitelist is a log parse operation binding the contract event 0xdc8d9026956e02a28f815d234adc27127f54ef34d8c43ebb214f52791f5df222.
//
// Solidity: event DecoderRemovedFromWhitelist(address indexed decoder)
func (_RelayerSentinel *RelayerSentinelFilterer) ParseDecoderRemovedFromWhitelist(log types.Log) (*RelayerSentinelDecoderRemovedFromWhitelist, error) {
	event := new(RelayerSentinelDecoderRemovedFromWhitelist)
	if err := _RelayerSentinel.contract.UnpackLog(event, "DecoderRemovedFromWhitelist", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RelayerSentinelDecoderWhitelistedIterator is returned from FilterDecoderWhitelisted and is used to iterate over the raw logs and unpacked data for DecoderWhitelisted events raised by the RelayerSentinel contract.
type RelayerSentinelDecoderWhitelistedIterator struct {
	Event *RelayerSentinelDecoderWhitelisted // Event containing the contract specifics and raw log

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
func (it *RelayerSentinelDecoderWhitelistedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RelayerSentinelDecoderWhitelisted)
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
		it.Event = new(RelayerSentinelDecoderWhitelisted)
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
func (it *RelayerSentinelDecoderWhitelistedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RelayerSentinelDecoderWhitelistedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RelayerSentinelDecoderWhitelisted represents a DecoderWhitelisted event raised by the RelayerSentinel contract.
type RelayerSentinelDecoderWhitelisted struct {
	Decoder common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterDecoderWhitelisted is a free log retrieval operation binding the contract event 0x90f779357fcf87c39478bf2115b821d2e9da213cb9af571dea122fd5cae06589.
//
// Solidity: event DecoderWhitelisted(address indexed decoder)
func (_RelayerSentinel *RelayerSentinelFilterer) FilterDecoderWhitelisted(opts *bind.FilterOpts, decoder []common.Address) (*RelayerSentinelDecoderWhitelistedIterator, error) {

	var decoderRule []interface{}
	for _, decoderItem := range decoder {
		decoderRule = append(decoderRule, decoderItem)
	}

	logs, sub, err := _RelayerSentinel.contract.FilterLogs(opts, "DecoderWhitelisted", decoderRule)
	if err != nil {
		return nil, err
	}
	return &RelayerSentinelDecoderWhitelistedIterator{contract: _RelayerSentinel.contract, event: "DecoderWhitelisted", logs: logs, sub: sub}, nil
}

// WatchDecoderWhitelisted is a free log subscription operation binding the contract event 0x90f779357fcf87c39478bf2115b821d2e9da213cb9af571dea122fd5cae06589.
//
// Solidity: event DecoderWhitelisted(address indexed decoder)
func (_RelayerSentinel *RelayerSentinelFilterer) WatchDecoderWhitelisted(opts *bind.WatchOpts, sink chan<- *RelayerSentinelDecoderWhitelisted, decoder []common.Address) (event.Subscription, error) {

	var decoderRule []interface{}
	for _, decoderItem := range decoder {
		decoderRule = append(decoderRule, decoderItem)
	}

	logs, sub, err := _RelayerSentinel.contract.WatchLogs(opts, "DecoderWhitelisted", decoderRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RelayerSentinelDecoderWhitelisted)
				if err := _RelayerSentinel.contract.UnpackLog(event, "DecoderWhitelisted", log); err != nil {
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

// ParseDecoderWhitelisted is a log parse operation binding the contract event 0x90f779357fcf87c39478bf2115b821d2e9da213cb9af571dea122fd5cae06589.
//
// Solidity: event DecoderWhitelisted(address indexed decoder)
func (_RelayerSentinel *RelayerSentinelFilterer) ParseDecoderWhitelisted(log types.Log) (*RelayerSentinelDecoderWhitelisted, error) {
	event := new(RelayerSentinelDecoderWhitelisted)
	if err := _RelayerSentinel.contract.UnpackLog(event, "DecoderWhitelisted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RelayerSentinelModuleNotificationTypeSetIterator is returned from FilterModuleNotificationTypeSet and is used to iterate over the raw logs and unpacked data for ModuleNotificationTypeSet events raised by the RelayerSentinel contract.
type RelayerSentinelModuleNotificationTypeSetIterator struct {
	Event *RelayerSentinelModuleNotificationTypeSet // Event containing the contract specifics and raw log

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
func (it *RelayerSentinelModuleNotificationTypeSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RelayerSentinelModuleNotificationTypeSet)
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
		it.Event = new(RelayerSentinelModuleNotificationTypeSet)
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
func (it *RelayerSentinelModuleNotificationTypeSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RelayerSentinelModuleNotificationTypeSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RelayerSentinelModuleNotificationTypeSet represents a ModuleNotificationTypeSet event raised by the RelayerSentinel contract.
type RelayerSentinelModuleNotificationTypeSet struct {
	Module           common.Address
	NotificationType uint8
	Raw              types.Log // Blockchain specific contextual infos
}

// FilterModuleNotificationTypeSet is a free log retrieval operation binding the contract event 0xc8810dcbc769e1fdc5259b29bdf28ff6637ea5eb3aa16e982ed3608a23b453db.
//
// Solidity: event ModuleNotificationTypeSet(address indexed module, uint8 notificationType)
func (_RelayerSentinel *RelayerSentinelFilterer) FilterModuleNotificationTypeSet(opts *bind.FilterOpts, module []common.Address) (*RelayerSentinelModuleNotificationTypeSetIterator, error) {

	var moduleRule []interface{}
	for _, moduleItem := range module {
		moduleRule = append(moduleRule, moduleItem)
	}

	logs, sub, err := _RelayerSentinel.contract.FilterLogs(opts, "ModuleNotificationTypeSet", moduleRule)
	if err != nil {
		return nil, err
	}
	return &RelayerSentinelModuleNotificationTypeSetIterator{contract: _RelayerSentinel.contract, event: "ModuleNotificationTypeSet", logs: logs, sub: sub}, nil
}

// WatchModuleNotificationTypeSet is a free log subscription operation binding the contract event 0xc8810dcbc769e1fdc5259b29bdf28ff6637ea5eb3aa16e982ed3608a23b453db.
//
// Solidity: event ModuleNotificationTypeSet(address indexed module, uint8 notificationType)
func (_RelayerSentinel *RelayerSentinelFilterer) WatchModuleNotificationTypeSet(opts *bind.WatchOpts, sink chan<- *RelayerSentinelModuleNotificationTypeSet, module []common.Address) (event.Subscription, error) {

	var moduleRule []interface{}
	for _, moduleItem := range module {
		moduleRule = append(moduleRule, moduleItem)
	}

	logs, sub, err := _RelayerSentinel.contract.WatchLogs(opts, "ModuleNotificationTypeSet", moduleRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RelayerSentinelModuleNotificationTypeSet)
				if err := _RelayerSentinel.contract.UnpackLog(event, "ModuleNotificationTypeSet", log); err != nil {
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

// ParseModuleNotificationTypeSet is a log parse operation binding the contract event 0xc8810dcbc769e1fdc5259b29bdf28ff6637ea5eb3aa16e982ed3608a23b453db.
//
// Solidity: event ModuleNotificationTypeSet(address indexed module, uint8 notificationType)
func (_RelayerSentinel *RelayerSentinelFilterer) ParseModuleNotificationTypeSet(log types.Log) (*RelayerSentinelModuleNotificationTypeSet, error) {
	event := new(RelayerSentinelModuleNotificationTypeSet)
	if err := _RelayerSentinel.contract.UnpackLog(event, "ModuleNotificationTypeSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RelayerSentinelModuleRemovedFromWhitelistIterator is returned from FilterModuleRemovedFromWhitelist and is used to iterate over the raw logs and unpacked data for ModuleRemovedFromWhitelist events raised by the RelayerSentinel contract.
type RelayerSentinelModuleRemovedFromWhitelistIterator struct {
	Event *RelayerSentinelModuleRemovedFromWhitelist // Event containing the contract specifics and raw log

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
func (it *RelayerSentinelModuleRemovedFromWhitelistIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RelayerSentinelModuleRemovedFromWhitelist)
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
		it.Event = new(RelayerSentinelModuleRemovedFromWhitelist)
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
func (it *RelayerSentinelModuleRemovedFromWhitelistIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RelayerSentinelModuleRemovedFromWhitelistIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RelayerSentinelModuleRemovedFromWhitelist represents a ModuleRemovedFromWhitelist event raised by the RelayerSentinel contract.
type RelayerSentinelModuleRemovedFromWhitelist struct {
	Module common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterModuleRemovedFromWhitelist is a free log retrieval operation binding the contract event 0xcc6feb9c4a950037d0ebabdc282627c1574abfedbc12b6a11fc324dd23d3f145.
//
// Solidity: event ModuleRemovedFromWhitelist(address indexed module)
func (_RelayerSentinel *RelayerSentinelFilterer) FilterModuleRemovedFromWhitelist(opts *bind.FilterOpts, module []common.Address) (*RelayerSentinelModuleRemovedFromWhitelistIterator, error) {

	var moduleRule []interface{}
	for _, moduleItem := range module {
		moduleRule = append(moduleRule, moduleItem)
	}

	logs, sub, err := _RelayerSentinel.contract.FilterLogs(opts, "ModuleRemovedFromWhitelist", moduleRule)
	if err != nil {
		return nil, err
	}
	return &RelayerSentinelModuleRemovedFromWhitelistIterator{contract: _RelayerSentinel.contract, event: "ModuleRemovedFromWhitelist", logs: logs, sub: sub}, nil
}

// WatchModuleRemovedFromWhitelist is a free log subscription operation binding the contract event 0xcc6feb9c4a950037d0ebabdc282627c1574abfedbc12b6a11fc324dd23d3f145.
//
// Solidity: event ModuleRemovedFromWhitelist(address indexed module)
func (_RelayerSentinel *RelayerSentinelFilterer) WatchModuleRemovedFromWhitelist(opts *bind.WatchOpts, sink chan<- *RelayerSentinelModuleRemovedFromWhitelist, module []common.Address) (event.Subscription, error) {

	var moduleRule []interface{}
	for _, moduleItem := range module {
		moduleRule = append(moduleRule, moduleItem)
	}

	logs, sub, err := _RelayerSentinel.contract.WatchLogs(opts, "ModuleRemovedFromWhitelist", moduleRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RelayerSentinelModuleRemovedFromWhitelist)
				if err := _RelayerSentinel.contract.UnpackLog(event, "ModuleRemovedFromWhitelist", log); err != nil {
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

// ParseModuleRemovedFromWhitelist is a log parse operation binding the contract event 0xcc6feb9c4a950037d0ebabdc282627c1574abfedbc12b6a11fc324dd23d3f145.
//
// Solidity: event ModuleRemovedFromWhitelist(address indexed module)
func (_RelayerSentinel *RelayerSentinelFilterer) ParseModuleRemovedFromWhitelist(log types.Log) (*RelayerSentinelModuleRemovedFromWhitelist, error) {
	event := new(RelayerSentinelModuleRemovedFromWhitelist)
	if err := _RelayerSentinel.contract.UnpackLog(event, "ModuleRemovedFromWhitelist", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RelayerSentinelModuleWhitelistedIterator is returned from FilterModuleWhitelisted and is used to iterate over the raw logs and unpacked data for ModuleWhitelisted events raised by the RelayerSentinel contract.
type RelayerSentinelModuleWhitelistedIterator struct {
	Event *RelayerSentinelModuleWhitelisted // Event containing the contract specifics and raw log

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
func (it *RelayerSentinelModuleWhitelistedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RelayerSentinelModuleWhitelisted)
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
		it.Event = new(RelayerSentinelModuleWhitelisted)
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
func (it *RelayerSentinelModuleWhitelistedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RelayerSentinelModuleWhitelistedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RelayerSentinelModuleWhitelisted represents a ModuleWhitelisted event raised by the RelayerSentinel contract.
type RelayerSentinelModuleWhitelisted struct {
	Module common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterModuleWhitelisted is a free log retrieval operation binding the contract event 0xb652e1c35eca29bf9ca732fa57b25baa999953139f10e0a376e4685c58e8aca5.
//
// Solidity: event ModuleWhitelisted(address indexed module)
func (_RelayerSentinel *RelayerSentinelFilterer) FilterModuleWhitelisted(opts *bind.FilterOpts, module []common.Address) (*RelayerSentinelModuleWhitelistedIterator, error) {

	var moduleRule []interface{}
	for _, moduleItem := range module {
		moduleRule = append(moduleRule, moduleItem)
	}

	logs, sub, err := _RelayerSentinel.contract.FilterLogs(opts, "ModuleWhitelisted", moduleRule)
	if err != nil {
		return nil, err
	}
	return &RelayerSentinelModuleWhitelistedIterator{contract: _RelayerSentinel.contract, event: "ModuleWhitelisted", logs: logs, sub: sub}, nil
}

// WatchModuleWhitelisted is a free log subscription operation binding the contract event 0xb652e1c35eca29bf9ca732fa57b25baa999953139f10e0a376e4685c58e8aca5.
//
// Solidity: event ModuleWhitelisted(address indexed module)
func (_RelayerSentinel *RelayerSentinelFilterer) WatchModuleWhitelisted(opts *bind.WatchOpts, sink chan<- *RelayerSentinelModuleWhitelisted, module []common.Address) (event.Subscription, error) {

	var moduleRule []interface{}
	for _, moduleItem := range module {
		moduleRule = append(moduleRule, moduleItem)
	}

	logs, sub, err := _RelayerSentinel.contract.WatchLogs(opts, "ModuleWhitelisted", moduleRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RelayerSentinelModuleWhitelisted)
				if err := _RelayerSentinel.contract.UnpackLog(event, "ModuleWhitelisted", log); err != nil {
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

// ParseModuleWhitelisted is a log parse operation binding the contract event 0xb652e1c35eca29bf9ca732fa57b25baa999953139f10e0a376e4685c58e8aca5.
//
// Solidity: event ModuleWhitelisted(address indexed module)
func (_RelayerSentinel *RelayerSentinelFilterer) ParseModuleWhitelisted(log types.Log) (*RelayerSentinelModuleWhitelisted, error) {
	event := new(RelayerSentinelModuleWhitelisted)
	if err := _RelayerSentinel.contract.UnpackLog(event, "ModuleWhitelisted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RelayerSentinelMsgIterator is returned from FilterMsg and is used to iterate over the raw logs and unpacked data for Msg events raised by the RelayerSentinel contract.
type RelayerSentinelMsgIterator struct {
	Event *RelayerSentinelMsg // Event containing the contract specifics and raw log

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
func (it *RelayerSentinelMsgIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RelayerSentinelMsg)
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
		it.Event = new(RelayerSentinelMsg)
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
func (it *RelayerSentinelMsgIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RelayerSentinelMsgIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RelayerSentinelMsg represents a Msg event raised by the RelayerSentinel contract.
type RelayerSentinelMsg struct {
	DestinationChainId  uint64
	DestinationContract common.Address
	Data                []byte
	Raw                 types.Log // Blockchain specific contextual infos
}

// FilterMsg is a free log retrieval operation binding the contract event 0x40d10bc6210625f540a70c1e761d4707547eeee98ada8431ff6b91556bbb9a6e.
//
// Solidity: event Msg(uint64 indexed destinationChainId, address indexed destinationContract, bytes data)
func (_RelayerSentinel *RelayerSentinelFilterer) FilterMsg(opts *bind.FilterOpts, destinationChainId []uint64, destinationContract []common.Address) (*RelayerSentinelMsgIterator, error) {

	var destinationChainIdRule []interface{}
	for _, destinationChainIdItem := range destinationChainId {
		destinationChainIdRule = append(destinationChainIdRule, destinationChainIdItem)
	}
	var destinationContractRule []interface{}
	for _, destinationContractItem := range destinationContract {
		destinationContractRule = append(destinationContractRule, destinationContractItem)
	}

	logs, sub, err := _RelayerSentinel.contract.FilterLogs(opts, "Msg", destinationChainIdRule, destinationContractRule)
	if err != nil {
		return nil, err
	}
	return &RelayerSentinelMsgIterator{contract: _RelayerSentinel.contract, event: "Msg", logs: logs, sub: sub}, nil
}

// WatchMsg is a free log subscription operation binding the contract event 0x40d10bc6210625f540a70c1e761d4707547eeee98ada8431ff6b91556bbb9a6e.
//
// Solidity: event Msg(uint64 indexed destinationChainId, address indexed destinationContract, bytes data)
func (_RelayerSentinel *RelayerSentinelFilterer) WatchMsg(opts *bind.WatchOpts, sink chan<- *RelayerSentinelMsg, destinationChainId []uint64, destinationContract []common.Address) (event.Subscription, error) {

	var destinationChainIdRule []interface{}
	for _, destinationChainIdItem := range destinationChainId {
		destinationChainIdRule = append(destinationChainIdRule, destinationChainIdItem)
	}
	var destinationContractRule []interface{}
	for _, destinationContractItem := range destinationContract {
		destinationContractRule = append(destinationContractRule, destinationContractItem)
	}

	logs, sub, err := _RelayerSentinel.contract.WatchLogs(opts, "Msg", destinationChainIdRule, destinationContractRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RelayerSentinelMsg)
				if err := _RelayerSentinel.contract.UnpackLog(event, "Msg", log); err != nil {
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

// ParseMsg is a log parse operation binding the contract event 0x40d10bc6210625f540a70c1e761d4707547eeee98ada8431ff6b91556bbb9a6e.
//
// Solidity: event Msg(uint64 indexed destinationChainId, address indexed destinationContract, bytes data)
func (_RelayerSentinel *RelayerSentinelFilterer) ParseMsg(log types.Log) (*RelayerSentinelMsg, error) {
	event := new(RelayerSentinelMsg)
	if err := _RelayerSentinel.contract.UnpackLog(event, "Msg", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RelayerSentinelSuperRegistrySetIterator is returned from FilterSuperRegistrySet and is used to iterate over the raw logs and unpacked data for SuperRegistrySet events raised by the RelayerSentinel contract.
type RelayerSentinelSuperRegistrySetIterator struct {
	Event *RelayerSentinelSuperRegistrySet // Event containing the contract specifics and raw log

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
func (it *RelayerSentinelSuperRegistrySetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RelayerSentinelSuperRegistrySet)
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
		it.Event = new(RelayerSentinelSuperRegistrySet)
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
func (it *RelayerSentinelSuperRegistrySetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RelayerSentinelSuperRegistrySetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RelayerSentinelSuperRegistrySet represents a SuperRegistrySet event raised by the RelayerSentinel contract.
type RelayerSentinelSuperRegistrySet struct {
	SuperRegistry common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterSuperRegistrySet is a free log retrieval operation binding the contract event 0x2eebcbfce9dd6cba1a52c0f9851fa11132c398a5aaaa5c605f536ef4d467b66b.
//
// Solidity: event SuperRegistrySet(address superRegistry)
func (_RelayerSentinel *RelayerSentinelFilterer) FilterSuperRegistrySet(opts *bind.FilterOpts) (*RelayerSentinelSuperRegistrySetIterator, error) {

	logs, sub, err := _RelayerSentinel.contract.FilterLogs(opts, "SuperRegistrySet")
	if err != nil {
		return nil, err
	}
	return &RelayerSentinelSuperRegistrySetIterator{contract: _RelayerSentinel.contract, event: "SuperRegistrySet", logs: logs, sub: sub}, nil
}

// WatchSuperRegistrySet is a free log subscription operation binding the contract event 0x2eebcbfce9dd6cba1a52c0f9851fa11132c398a5aaaa5c605f536ef4d467b66b.
//
// Solidity: event SuperRegistrySet(address superRegistry)
func (_RelayerSentinel *RelayerSentinelFilterer) WatchSuperRegistrySet(opts *bind.WatchOpts, sink chan<- *RelayerSentinelSuperRegistrySet) (event.Subscription, error) {

	logs, sub, err := _RelayerSentinel.contract.WatchLogs(opts, "SuperRegistrySet")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RelayerSentinelSuperRegistrySet)
				if err := _RelayerSentinel.contract.UnpackLog(event, "SuperRegistrySet", log); err != nil {
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

// ParseSuperRegistrySet is a log parse operation binding the contract event 0x2eebcbfce9dd6cba1a52c0f9851fa11132c398a5aaaa5c605f536ef4d467b66b.
//
// Solidity: event SuperRegistrySet(address superRegistry)
func (_RelayerSentinel *RelayerSentinelFilterer) ParseSuperRegistrySet(log types.Log) (*RelayerSentinelSuperRegistrySet, error) {
	event := new(RelayerSentinelSuperRegistrySet)
	if err := _RelayerSentinel.contract.UnpackLog(event, "SuperRegistrySet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RelayerSentinelWhitelistedHookIterator is returned from FilterWhitelistedHook and is used to iterate over the raw logs and unpacked data for WhitelistedHook events raised by the RelayerSentinel contract.
type RelayerSentinelWhitelistedHookIterator struct {
	Event *RelayerSentinelWhitelistedHook // Event containing the contract specifics and raw log

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
func (it *RelayerSentinelWhitelistedHookIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RelayerSentinelWhitelistedHook)
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
		it.Event = new(RelayerSentinelWhitelistedHook)
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
func (it *RelayerSentinelWhitelistedHookIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RelayerSentinelWhitelistedHookIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RelayerSentinelWhitelistedHook represents a WhitelistedHook event raised by the RelayerSentinel contract.
type RelayerSentinelWhitelistedHook struct {
	Hook    common.Address
	Allowed bool
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterWhitelistedHook is a free log retrieval operation binding the contract event 0x91fe9b1ce6cfea50f9f5040be07f649a8dc216e00b5b5602b4edf34a54dd8261.
//
// Solidity: event WhitelistedHook(address hook, bool allowed)
func (_RelayerSentinel *RelayerSentinelFilterer) FilterWhitelistedHook(opts *bind.FilterOpts) (*RelayerSentinelWhitelistedHookIterator, error) {

	logs, sub, err := _RelayerSentinel.contract.FilterLogs(opts, "WhitelistedHook")
	if err != nil {
		return nil, err
	}
	return &RelayerSentinelWhitelistedHookIterator{contract: _RelayerSentinel.contract, event: "WhitelistedHook", logs: logs, sub: sub}, nil
}

// WatchWhitelistedHook is a free log subscription operation binding the contract event 0x91fe9b1ce6cfea50f9f5040be07f649a8dc216e00b5b5602b4edf34a54dd8261.
//
// Solidity: event WhitelistedHook(address hook, bool allowed)
func (_RelayerSentinel *RelayerSentinelFilterer) WatchWhitelistedHook(opts *bind.WatchOpts, sink chan<- *RelayerSentinelWhitelistedHook) (event.Subscription, error) {

	logs, sub, err := _RelayerSentinel.contract.WatchLogs(opts, "WhitelistedHook")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RelayerSentinelWhitelistedHook)
				if err := _RelayerSentinel.contract.UnpackLog(event, "WhitelistedHook", log); err != nil {
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

// ParseWhitelistedHook is a log parse operation binding the contract event 0x91fe9b1ce6cfea50f9f5040be07f649a8dc216e00b5b5602b4edf34a54dd8261.
//
// Solidity: event WhitelistedHook(address hook, bool allowed)
func (_RelayerSentinel *RelayerSentinelFilterer) ParseWhitelistedHook(log types.Log) (*RelayerSentinelWhitelistedHook, error) {
	event := new(RelayerSentinelWhitelistedHook)
	if err := _RelayerSentinel.contract.UnpackLog(event, "WhitelistedHook", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
