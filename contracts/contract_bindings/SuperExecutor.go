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

// SuperExecutorMetaData contains all meta data concerning the SuperExecutor contract.
var SuperExecutorMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"registry_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"execute\",\"inputs\":[{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"executeFromGateway\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isInitialized\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isModuleType\",\"inputs\":[{\"name\":\"typeID\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"name\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"onInstall\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"onUninstall\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"superRegistry\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperRegistry\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"version\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"pure\"},{\"type\":\"error\",\"name\":\"ALREADY_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AlreadyInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"NOT_AUTHORIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]}]",
}

// SuperExecutorABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperExecutorMetaData.ABI instead.
var SuperExecutorABI = SuperExecutorMetaData.ABI

// SuperExecutor is an auto generated Go binding around an Ethereum contract.
type SuperExecutor struct {
	SuperExecutorCaller     // Read-only binding to the contract
	SuperExecutorTransactor // Write-only binding to the contract
	SuperExecutorFilterer   // Log filterer for contract events
}

// SuperExecutorCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperExecutorCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperExecutorTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperExecutorTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperExecutorFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperExecutorFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperExecutorSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperExecutorSession struct {
	Contract     *SuperExecutor    // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// SuperExecutorCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperExecutorCallerSession struct {
	Contract *SuperExecutorCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts        // Call options to use throughout this session
}

// SuperExecutorTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperExecutorTransactorSession struct {
	Contract     *SuperExecutorTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts        // Transaction auth options to use throughout this session
}

// SuperExecutorRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperExecutorRaw struct {
	Contract *SuperExecutor // Generic contract binding to access the raw methods on
}

// SuperExecutorCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperExecutorCallerRaw struct {
	Contract *SuperExecutorCaller // Generic read-only contract binding to access the raw methods on
}

// SuperExecutorTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperExecutorTransactorRaw struct {
	Contract *SuperExecutorTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperExecutor creates a new instance of SuperExecutor, bound to a specific deployed contract.
func NewSuperExecutor(address common.Address, backend bind.ContractBackend) (*SuperExecutor, error) {
	contract, err := bindSuperExecutor(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperExecutor{SuperExecutorCaller: SuperExecutorCaller{contract: contract}, SuperExecutorTransactor: SuperExecutorTransactor{contract: contract}, SuperExecutorFilterer: SuperExecutorFilterer{contract: contract}}, nil
}

// NewSuperExecutorCaller creates a new read-only instance of SuperExecutor, bound to a specific deployed contract.
func NewSuperExecutorCaller(address common.Address, caller bind.ContractCaller) (*SuperExecutorCaller, error) {
	contract, err := bindSuperExecutor(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperExecutorCaller{contract: contract}, nil
}

// NewSuperExecutorTransactor creates a new write-only instance of SuperExecutor, bound to a specific deployed contract.
func NewSuperExecutorTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperExecutorTransactor, error) {
	contract, err := bindSuperExecutor(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperExecutorTransactor{contract: contract}, nil
}

// NewSuperExecutorFilterer creates a new log filterer instance of SuperExecutor, bound to a specific deployed contract.
func NewSuperExecutorFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperExecutorFilterer, error) {
	contract, err := bindSuperExecutor(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperExecutorFilterer{contract: contract}, nil
}

// bindSuperExecutor binds a generic wrapper to an already deployed contract.
func bindSuperExecutor(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperExecutorMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperExecutor *SuperExecutorRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperExecutor.Contract.SuperExecutorCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperExecutor *SuperExecutorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperExecutor.Contract.SuperExecutorTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperExecutor *SuperExecutorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperExecutor.Contract.SuperExecutorTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperExecutor *SuperExecutorCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperExecutor.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperExecutor *SuperExecutorTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperExecutor.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperExecutor *SuperExecutorTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperExecutor.Contract.contract.Transact(opts, method, params...)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperExecutor *SuperExecutorCaller) IsInitialized(opts *bind.CallOpts, account common.Address) (bool, error) {
	var out []interface{}
	err := _SuperExecutor.contract.Call(opts, &out, "isInitialized", account)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperExecutor *SuperExecutorSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperExecutor.Contract.IsInitialized(&_SuperExecutor.CallOpts, account)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperExecutor *SuperExecutorCallerSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperExecutor.Contract.IsInitialized(&_SuperExecutor.CallOpts, account)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeID) pure returns(bool)
func (_SuperExecutor *SuperExecutorCaller) IsModuleType(opts *bind.CallOpts, typeID *big.Int) (bool, error) {
	var out []interface{}
	err := _SuperExecutor.contract.Call(opts, &out, "isModuleType", typeID)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeID) pure returns(bool)
func (_SuperExecutor *SuperExecutorSession) IsModuleType(typeID *big.Int) (bool, error) {
	return _SuperExecutor.Contract.IsModuleType(&_SuperExecutor.CallOpts, typeID)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeID) pure returns(bool)
func (_SuperExecutor *SuperExecutorCallerSession) IsModuleType(typeID *big.Int) (bool, error) {
	return _SuperExecutor.Contract.IsModuleType(&_SuperExecutor.CallOpts, typeID)
}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() pure returns(string)
func (_SuperExecutor *SuperExecutorCaller) Name(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperExecutor.contract.Call(opts, &out, "name")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() pure returns(string)
func (_SuperExecutor *SuperExecutorSession) Name() (string, error) {
	return _SuperExecutor.Contract.Name(&_SuperExecutor.CallOpts)
}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() pure returns(string)
func (_SuperExecutor *SuperExecutorCallerSession) Name() (string, error) {
	return _SuperExecutor.Contract.Name(&_SuperExecutor.CallOpts)
}

// SuperRegistry is a free data retrieval call binding the contract method 0x24c73dda.
//
// Solidity: function superRegistry() view returns(address)
func (_SuperExecutor *SuperExecutorCaller) SuperRegistry(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperExecutor.contract.Call(opts, &out, "superRegistry")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SuperRegistry is a free data retrieval call binding the contract method 0x24c73dda.
//
// Solidity: function superRegistry() view returns(address)
func (_SuperExecutor *SuperExecutorSession) SuperRegistry() (common.Address, error) {
	return _SuperExecutor.Contract.SuperRegistry(&_SuperExecutor.CallOpts)
}

// SuperRegistry is a free data retrieval call binding the contract method 0x24c73dda.
//
// Solidity: function superRegistry() view returns(address)
func (_SuperExecutor *SuperExecutorCallerSession) SuperRegistry() (common.Address, error) {
	return _SuperExecutor.Contract.SuperRegistry(&_SuperExecutor.CallOpts)
}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() pure returns(string)
func (_SuperExecutor *SuperExecutorCaller) Version(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperExecutor.contract.Call(opts, &out, "version")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() pure returns(string)
func (_SuperExecutor *SuperExecutorSession) Version() (string, error) {
	return _SuperExecutor.Contract.Version(&_SuperExecutor.CallOpts)
}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() pure returns(string)
func (_SuperExecutor *SuperExecutorCallerSession) Version() (string, error) {
	return _SuperExecutor.Contract.Version(&_SuperExecutor.CallOpts)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_SuperExecutor *SuperExecutorTransactor) Execute(opts *bind.TransactOpts, data []byte) (*types.Transaction, error) {
	return _SuperExecutor.contract.Transact(opts, "execute", data)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_SuperExecutor *SuperExecutorSession) Execute(data []byte) (*types.Transaction, error) {
	return _SuperExecutor.Contract.Execute(&_SuperExecutor.TransactOpts, data)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_SuperExecutor *SuperExecutorTransactorSession) Execute(data []byte) (*types.Transaction, error) {
	return _SuperExecutor.Contract.Execute(&_SuperExecutor.TransactOpts, data)
}

// ExecuteFromGateway is a paid mutator transaction binding the contract method 0x17429edd.
//
// Solidity: function executeFromGateway(address account, bytes data) returns()
func (_SuperExecutor *SuperExecutorTransactor) ExecuteFromGateway(opts *bind.TransactOpts, account common.Address, data []byte) (*types.Transaction, error) {
	return _SuperExecutor.contract.Transact(opts, "executeFromGateway", account, data)
}

// ExecuteFromGateway is a paid mutator transaction binding the contract method 0x17429edd.
//
// Solidity: function executeFromGateway(address account, bytes data) returns()
func (_SuperExecutor *SuperExecutorSession) ExecuteFromGateway(account common.Address, data []byte) (*types.Transaction, error) {
	return _SuperExecutor.Contract.ExecuteFromGateway(&_SuperExecutor.TransactOpts, account, data)
}

// ExecuteFromGateway is a paid mutator transaction binding the contract method 0x17429edd.
//
// Solidity: function executeFromGateway(address account, bytes data) returns()
func (_SuperExecutor *SuperExecutorTransactorSession) ExecuteFromGateway(account common.Address, data []byte) (*types.Transaction, error) {
	return _SuperExecutor.Contract.ExecuteFromGateway(&_SuperExecutor.TransactOpts, account, data)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_SuperExecutor *SuperExecutorTransactor) OnInstall(opts *bind.TransactOpts, arg0 []byte) (*types.Transaction, error) {
	return _SuperExecutor.contract.Transact(opts, "onInstall", arg0)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_SuperExecutor *SuperExecutorSession) OnInstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperExecutor.Contract.OnInstall(&_SuperExecutor.TransactOpts, arg0)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_SuperExecutor *SuperExecutorTransactorSession) OnInstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperExecutor.Contract.OnInstall(&_SuperExecutor.TransactOpts, arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperExecutor *SuperExecutorTransactor) OnUninstall(opts *bind.TransactOpts, arg0 []byte) (*types.Transaction, error) {
	return _SuperExecutor.contract.Transact(opts, "onUninstall", arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperExecutor *SuperExecutorSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperExecutor.Contract.OnUninstall(&_SuperExecutor.TransactOpts, arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperExecutor *SuperExecutorTransactorSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperExecutor.Contract.OnUninstall(&_SuperExecutor.TransactOpts, arg0)
}
