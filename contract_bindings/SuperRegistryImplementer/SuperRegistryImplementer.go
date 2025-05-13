// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperRegistryImplementer

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

// SuperRegistryImplementerMetaData contains all meta data concerning the SuperRegistryImplementer contract.
var SuperRegistryImplementerMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"superRegistry\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperRegistry\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]}]",
}

// SuperRegistryImplementerABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperRegistryImplementerMetaData.ABI instead.
var SuperRegistryImplementerABI = SuperRegistryImplementerMetaData.ABI

// SuperRegistryImplementer is an auto generated Go binding around an Ethereum contract.
type SuperRegistryImplementer struct {
	SuperRegistryImplementerCaller     // Read-only binding to the contract
	SuperRegistryImplementerTransactor // Write-only binding to the contract
	SuperRegistryImplementerFilterer   // Log filterer for contract events
}

// SuperRegistryImplementerCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperRegistryImplementerCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperRegistryImplementerTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperRegistryImplementerTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperRegistryImplementerFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperRegistryImplementerFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperRegistryImplementerSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperRegistryImplementerSession struct {
	Contract     *SuperRegistryImplementer // Generic contract binding to set the session for
	CallOpts     bind.CallOpts             // Call options to use throughout this session
	TransactOpts bind.TransactOpts         // Transaction auth options to use throughout this session
}

// SuperRegistryImplementerCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperRegistryImplementerCallerSession struct {
	Contract *SuperRegistryImplementerCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                   // Call options to use throughout this session
}

// SuperRegistryImplementerTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperRegistryImplementerTransactorSession struct {
	Contract     *SuperRegistryImplementerTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                   // Transaction auth options to use throughout this session
}

// SuperRegistryImplementerRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperRegistryImplementerRaw struct {
	Contract *SuperRegistryImplementer // Generic contract binding to access the raw methods on
}

// SuperRegistryImplementerCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperRegistryImplementerCallerRaw struct {
	Contract *SuperRegistryImplementerCaller // Generic read-only contract binding to access the raw methods on
}

// SuperRegistryImplementerTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperRegistryImplementerTransactorRaw struct {
	Contract *SuperRegistryImplementerTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperRegistryImplementer creates a new instance of SuperRegistryImplementer, bound to a specific deployed contract.
func NewSuperRegistryImplementer(address common.Address, backend bind.ContractBackend) (*SuperRegistryImplementer, error) {
	contract, err := bindSuperRegistryImplementer(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperRegistryImplementer{SuperRegistryImplementerCaller: SuperRegistryImplementerCaller{contract: contract}, SuperRegistryImplementerTransactor: SuperRegistryImplementerTransactor{contract: contract}, SuperRegistryImplementerFilterer: SuperRegistryImplementerFilterer{contract: contract}}, nil
}

// NewSuperRegistryImplementerCaller creates a new read-only instance of SuperRegistryImplementer, bound to a specific deployed contract.
func NewSuperRegistryImplementerCaller(address common.Address, caller bind.ContractCaller) (*SuperRegistryImplementerCaller, error) {
	contract, err := bindSuperRegistryImplementer(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperRegistryImplementerCaller{contract: contract}, nil
}

// NewSuperRegistryImplementerTransactor creates a new write-only instance of SuperRegistryImplementer, bound to a specific deployed contract.
func NewSuperRegistryImplementerTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperRegistryImplementerTransactor, error) {
	contract, err := bindSuperRegistryImplementer(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperRegistryImplementerTransactor{contract: contract}, nil
}

// NewSuperRegistryImplementerFilterer creates a new log filterer instance of SuperRegistryImplementer, bound to a specific deployed contract.
func NewSuperRegistryImplementerFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperRegistryImplementerFilterer, error) {
	contract, err := bindSuperRegistryImplementer(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperRegistryImplementerFilterer{contract: contract}, nil
}

// bindSuperRegistryImplementer binds a generic wrapper to an already deployed contract.
func bindSuperRegistryImplementer(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperRegistryImplementerMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperRegistryImplementer *SuperRegistryImplementerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperRegistryImplementer.Contract.SuperRegistryImplementerCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperRegistryImplementer *SuperRegistryImplementerRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperRegistryImplementer.Contract.SuperRegistryImplementerTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperRegistryImplementer *SuperRegistryImplementerRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperRegistryImplementer.Contract.SuperRegistryImplementerTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperRegistryImplementer *SuperRegistryImplementerCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperRegistryImplementer.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperRegistryImplementer *SuperRegistryImplementerTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperRegistryImplementer.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperRegistryImplementer *SuperRegistryImplementerTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperRegistryImplementer.Contract.contract.Transact(opts, method, params...)
}

// SuperRegistry is a free data retrieval call binding the contract method 0x24c73dda.
//
// Solidity: function superRegistry() view returns(address)
func (_SuperRegistryImplementer *SuperRegistryImplementerCaller) SuperRegistry(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperRegistryImplementer.contract.Call(opts, &out, "superRegistry")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SuperRegistry is a free data retrieval call binding the contract method 0x24c73dda.
//
// Solidity: function superRegistry() view returns(address)
func (_SuperRegistryImplementer *SuperRegistryImplementerSession) SuperRegistry() (common.Address, error) {
	return _SuperRegistryImplementer.Contract.SuperRegistry(&_SuperRegistryImplementer.CallOpts)
}

// SuperRegistry is a free data retrieval call binding the contract method 0x24c73dda.
//
// Solidity: function superRegistry() view returns(address)
func (_SuperRegistryImplementer *SuperRegistryImplementerCallerSession) SuperRegistry() (common.Address, error) {
	return _SuperRegistryImplementer.Contract.SuperRegistry(&_SuperRegistryImplementer.CallOpts)
}
