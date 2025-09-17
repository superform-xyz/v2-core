// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package ERC7484RegistryAdapter

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

// ERC7484RegistryAdapterMetaData contains all meta data concerning the ERC7484RegistryAdapter contract.
var ERC7484RegistryAdapterMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"REGISTRY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIERC7484\"}],\"stateMutability\":\"view\"}]",
}

// ERC7484RegistryAdapterABI is the input ABI used to generate the binding from.
// Deprecated: Use ERC7484RegistryAdapterMetaData.ABI instead.
var ERC7484RegistryAdapterABI = ERC7484RegistryAdapterMetaData.ABI

// ERC7484RegistryAdapter is an auto generated Go binding around an Ethereum contract.
type ERC7484RegistryAdapter struct {
	ERC7484RegistryAdapterCaller     // Read-only binding to the contract
	ERC7484RegistryAdapterTransactor // Write-only binding to the contract
	ERC7484RegistryAdapterFilterer   // Log filterer for contract events
}

// ERC7484RegistryAdapterCaller is an auto generated read-only Go binding around an Ethereum contract.
type ERC7484RegistryAdapterCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ERC7484RegistryAdapterTransactor is an auto generated write-only Go binding around an Ethereum contract.
type ERC7484RegistryAdapterTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ERC7484RegistryAdapterFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type ERC7484RegistryAdapterFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ERC7484RegistryAdapterSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type ERC7484RegistryAdapterSession struct {
	Contract     *ERC7484RegistryAdapter // Generic contract binding to set the session for
	CallOpts     bind.CallOpts           // Call options to use throughout this session
	TransactOpts bind.TransactOpts       // Transaction auth options to use throughout this session
}

// ERC7484RegistryAdapterCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type ERC7484RegistryAdapterCallerSession struct {
	Contract *ERC7484RegistryAdapterCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                 // Call options to use throughout this session
}

// ERC7484RegistryAdapterTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type ERC7484RegistryAdapterTransactorSession struct {
	Contract     *ERC7484RegistryAdapterTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                 // Transaction auth options to use throughout this session
}

// ERC7484RegistryAdapterRaw is an auto generated low-level Go binding around an Ethereum contract.
type ERC7484RegistryAdapterRaw struct {
	Contract *ERC7484RegistryAdapter // Generic contract binding to access the raw methods on
}

// ERC7484RegistryAdapterCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type ERC7484RegistryAdapterCallerRaw struct {
	Contract *ERC7484RegistryAdapterCaller // Generic read-only contract binding to access the raw methods on
}

// ERC7484RegistryAdapterTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type ERC7484RegistryAdapterTransactorRaw struct {
	Contract *ERC7484RegistryAdapterTransactor // Generic write-only contract binding to access the raw methods on
}

// NewERC7484RegistryAdapter creates a new instance of ERC7484RegistryAdapter, bound to a specific deployed contract.
func NewERC7484RegistryAdapter(address common.Address, backend bind.ContractBackend) (*ERC7484RegistryAdapter, error) {
	contract, err := bindERC7484RegistryAdapter(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &ERC7484RegistryAdapter{ERC7484RegistryAdapterCaller: ERC7484RegistryAdapterCaller{contract: contract}, ERC7484RegistryAdapterTransactor: ERC7484RegistryAdapterTransactor{contract: contract}, ERC7484RegistryAdapterFilterer: ERC7484RegistryAdapterFilterer{contract: contract}}, nil
}

// NewERC7484RegistryAdapterCaller creates a new read-only instance of ERC7484RegistryAdapter, bound to a specific deployed contract.
func NewERC7484RegistryAdapterCaller(address common.Address, caller bind.ContractCaller) (*ERC7484RegistryAdapterCaller, error) {
	contract, err := bindERC7484RegistryAdapter(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &ERC7484RegistryAdapterCaller{contract: contract}, nil
}

// NewERC7484RegistryAdapterTransactor creates a new write-only instance of ERC7484RegistryAdapter, bound to a specific deployed contract.
func NewERC7484RegistryAdapterTransactor(address common.Address, transactor bind.ContractTransactor) (*ERC7484RegistryAdapterTransactor, error) {
	contract, err := bindERC7484RegistryAdapter(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &ERC7484RegistryAdapterTransactor{contract: contract}, nil
}

// NewERC7484RegistryAdapterFilterer creates a new log filterer instance of ERC7484RegistryAdapter, bound to a specific deployed contract.
func NewERC7484RegistryAdapterFilterer(address common.Address, filterer bind.ContractFilterer) (*ERC7484RegistryAdapterFilterer, error) {
	contract, err := bindERC7484RegistryAdapter(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &ERC7484RegistryAdapterFilterer{contract: contract}, nil
}

// bindERC7484RegistryAdapter binds a generic wrapper to an already deployed contract.
func bindERC7484RegistryAdapter(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := ERC7484RegistryAdapterMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ERC7484RegistryAdapter *ERC7484RegistryAdapterRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ERC7484RegistryAdapter.Contract.ERC7484RegistryAdapterCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ERC7484RegistryAdapter *ERC7484RegistryAdapterRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ERC7484RegistryAdapter.Contract.ERC7484RegistryAdapterTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ERC7484RegistryAdapter *ERC7484RegistryAdapterRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ERC7484RegistryAdapter.Contract.ERC7484RegistryAdapterTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ERC7484RegistryAdapter *ERC7484RegistryAdapterCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ERC7484RegistryAdapter.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ERC7484RegistryAdapter *ERC7484RegistryAdapterTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ERC7484RegistryAdapter.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ERC7484RegistryAdapter *ERC7484RegistryAdapterTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ERC7484RegistryAdapter.Contract.contract.Transact(opts, method, params...)
}

// REGISTRY is a free data retrieval call binding the contract method 0x06433b1b.
//
// Solidity: function REGISTRY() view returns(address)
func (_ERC7484RegistryAdapter *ERC7484RegistryAdapterCaller) REGISTRY(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ERC7484RegistryAdapter.contract.Call(opts, &out, "REGISTRY")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// REGISTRY is a free data retrieval call binding the contract method 0x06433b1b.
//
// Solidity: function REGISTRY() view returns(address)
func (_ERC7484RegistryAdapter *ERC7484RegistryAdapterSession) REGISTRY() (common.Address, error) {
	return _ERC7484RegistryAdapter.Contract.REGISTRY(&_ERC7484RegistryAdapter.CallOpts)
}

// REGISTRY is a free data retrieval call binding the contract method 0x06433b1b.
//
// Solidity: function REGISTRY() view returns(address)
func (_ERC7484RegistryAdapter *ERC7484RegistryAdapterCallerSession) REGISTRY() (common.Address, error) {
	return _ERC7484RegistryAdapter.Contract.REGISTRY(&_ERC7484RegistryAdapter.CallOpts)
}
