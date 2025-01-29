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

// SuperExecutorV2MetaData contains all meta data concerning the SuperExecutor contract.
var SuperExecutorV2MetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"registry_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"execute\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"executeFromGateway\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isInitialized\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"isModuleType\",\"inputs\":[{\"name\":\"typeID\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"name\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"onInstall\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"onUninstall\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"superActions\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"superRegistry\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperRegistry\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"version\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"pure\"},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AMOUNT_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AlreadyInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"DATA_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_AUTHORIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]}]",
}

// SuperExecutorV2ABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperExecutorV2MetaData.ABI instead.
var SuperExecutorV2ABI = SuperExecutorV2MetaData.ABI

// SuperExecutor is an auto generated Go binding around an Ethereum contract.
type SuperExecutor struct {
	SuperExecutorV2Caller     // Read-only binding to the contract
	SuperExecutorV2Transactor // Write-only binding to the contract
	SuperExecutorV2Filterer   // Log filterer for contract events
}

// SuperExecutorV2Caller is an auto generated read-only Go binding around an Ethereum contract.
type SuperExecutorV2Caller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperExecutorV2Transactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperExecutorV2Transactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperExecutorV2Filterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperExecutorV2Filterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperExecutorV2Session is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperExecutorV2Session struct {
	Contract     *SuperExecutor  // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// SuperExecutorV2CallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperExecutorV2CallerSession struct {
	Contract *SuperExecutorV2Caller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts          // Call options to use throughout this session
}

// SuperExecutorV2TransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperExecutorV2TransactorSession struct {
	Contract     *SuperExecutorV2Transactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts          // Transaction auth options to use throughout this session
}

// SuperExecutorV2Raw is an auto generated low-level Go binding around an Ethereum contract.
type SuperExecutorV2Raw struct {
	Contract *SuperExecutor // Generic contract binding to access the raw methods on
}

// SuperExecutorV2CallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperExecutorV2CallerRaw struct {
	Contract *SuperExecutorV2Caller // Generic read-only contract binding to access the raw methods on
}

// SuperExecutorV2TransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperExecutorV2TransactorRaw struct {
	Contract *SuperExecutorV2Transactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperExecutorV2 creates a new instance of SuperExecutor, bound to a specific deployed contract.
func NewSuperExecutorV2(address common.Address, backend bind.ContractBackend) (*SuperExecutor, error) {
	contract, err := bindSuperExecutorV2(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperExecutor{SuperExecutorV2Caller: SuperExecutorV2Caller{contract: contract}, SuperExecutorV2Transactor: SuperExecutorV2Transactor{contract: contract}, SuperExecutorV2Filterer: SuperExecutorV2Filterer{contract: contract}}, nil
}

// NewSuperExecutorV2Caller creates a new read-only instance of SuperExecutor, bound to a specific deployed contract.
func NewSuperExecutorV2Caller(address common.Address, caller bind.ContractCaller) (*SuperExecutorV2Caller, error) {
	contract, err := bindSuperExecutorV2(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperExecutorV2Caller{contract: contract}, nil
}

// NewSuperExecutorV2Transactor creates a new write-only instance of SuperExecutor, bound to a specific deployed contract.
func NewSuperExecutorV2Transactor(address common.Address, transactor bind.ContractTransactor) (*SuperExecutorV2Transactor, error) {
	contract, err := bindSuperExecutorV2(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperExecutorV2Transactor{contract: contract}, nil
}

// NewSuperExecutorV2Filterer creates a new log filterer instance of SuperExecutor, bound to a specific deployed contract.
func NewSuperExecutorV2Filterer(address common.Address, filterer bind.ContractFilterer) (*SuperExecutorV2Filterer, error) {
	contract, err := bindSuperExecutorV2(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperExecutorV2Filterer{contract: contract}, nil
}

// bindSuperExecutorV2 binds a generic wrapper to an already deployed contract.
func bindSuperExecutorV2(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperExecutorV2MetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperExecutorV2 *SuperExecutorV2Raw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperExecutorV2.Contract.SuperExecutorV2Caller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperExecutorV2 *SuperExecutorV2Raw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperExecutorV2.Contract.SuperExecutorV2Transactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperExecutorV2 *SuperExecutorV2Raw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperExecutorV2.Contract.SuperExecutorV2Transactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperExecutorV2 *SuperExecutorV2CallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperExecutorV2.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperExecutorV2 *SuperExecutorV2TransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperExecutorV2.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperExecutorV2 *SuperExecutorV2TransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperExecutorV2.Contract.contract.Transact(opts, method, params...)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address ) pure returns(bool)
func (_SuperExecutorV2 *SuperExecutorV2Caller) IsInitialized(opts *bind.CallOpts, arg0 common.Address) (bool, error) {
	var out []interface{}
	err := _SuperExecutorV2.contract.Call(opts, &out, "isInitialized", arg0)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address ) pure returns(bool)
func (_SuperExecutorV2 *SuperExecutorV2Session) IsInitialized(arg0 common.Address) (bool, error) {
	return _SuperExecutorV2.Contract.IsInitialized(&_SuperExecutorV2.CallOpts, arg0)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address ) pure returns(bool)
func (_SuperExecutorV2 *SuperExecutorV2CallerSession) IsInitialized(arg0 common.Address) (bool, error) {
	return _SuperExecutorV2.Contract.IsInitialized(&_SuperExecutorV2.CallOpts, arg0)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeID) pure returns(bool)
func (_SuperExecutorV2 *SuperExecutorV2Caller) IsModuleType(opts *bind.CallOpts, typeID *big.Int) (bool, error) {
	var out []interface{}
	err := _SuperExecutorV2.contract.Call(opts, &out, "isModuleType", typeID)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeID) pure returns(bool)
func (_SuperExecutorV2 *SuperExecutorV2Session) IsModuleType(typeID *big.Int) (bool, error) {
	return _SuperExecutorV2.Contract.IsModuleType(&_SuperExecutorV2.CallOpts, typeID)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeID) pure returns(bool)
func (_SuperExecutorV2 *SuperExecutorV2CallerSession) IsModuleType(typeID *big.Int) (bool, error) {
	return _SuperExecutorV2.Contract.IsModuleType(&_SuperExecutorV2.CallOpts, typeID)
}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() pure returns(string)
func (_SuperExecutorV2 *SuperExecutorV2Caller) Name(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperExecutorV2.contract.Call(opts, &out, "name")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() pure returns(string)
func (_SuperExecutorV2 *SuperExecutorV2Session) Name() (string, error) {
	return _SuperExecutorV2.Contract.Name(&_SuperExecutorV2.CallOpts)
}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() pure returns(string)
func (_SuperExecutorV2 *SuperExecutorV2CallerSession) Name() (string, error) {
	return _SuperExecutorV2.Contract.Name(&_SuperExecutorV2.CallOpts)
}

// SuperActions is a free data retrieval call binding the contract method 0x40e98cf6.
//
// Solidity: function superActions() view returns(address)
func (_SuperExecutorV2 *SuperExecutorV2Caller) SuperActions(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperExecutorV2.contract.Call(opts, &out, "superActions")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SuperActions is a free data retrieval call binding the contract method 0x40e98cf6.
//
// Solidity: function superActions() view returns(address)
func (_SuperExecutorV2 *SuperExecutorV2Session) SuperActions() (common.Address, error) {
	return _SuperExecutorV2.Contract.SuperActions(&_SuperExecutorV2.CallOpts)
}

// SuperActions is a free data retrieval call binding the contract method 0x40e98cf6.
//
// Solidity: function superActions() view returns(address)
func (_SuperExecutorV2 *SuperExecutorV2CallerSession) SuperActions() (common.Address, error) {
	return _SuperExecutorV2.Contract.SuperActions(&_SuperExecutorV2.CallOpts)
}

// SuperRegistry is a free data retrieval call binding the contract method 0x24c73dda.
//
// Solidity: function superRegistry() view returns(address)
func (_SuperExecutorV2 *SuperExecutorV2Caller) SuperRegistry(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperExecutorV2.contract.Call(opts, &out, "superRegistry")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SuperRegistry is a free data retrieval call binding the contract method 0x24c73dda.
//
// Solidity: function superRegistry() view returns(address)
func (_SuperExecutorV2 *SuperExecutorV2Session) SuperRegistry() (common.Address, error) {
	return _SuperExecutorV2.Contract.SuperRegistry(&_SuperExecutorV2.CallOpts)
}

// SuperRegistry is a free data retrieval call binding the contract method 0x24c73dda.
//
// Solidity: function superRegistry() view returns(address)
func (_SuperExecutorV2 *SuperExecutorV2CallerSession) SuperRegistry() (common.Address, error) {
	return _SuperExecutorV2.Contract.SuperRegistry(&_SuperExecutorV2.CallOpts)
}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() pure returns(string)
func (_SuperExecutorV2 *SuperExecutorV2Caller) Version(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperExecutorV2.contract.Call(opts, &out, "version")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() pure returns(string)
func (_SuperExecutorV2 *SuperExecutorV2Session) Version() (string, error) {
	return _SuperExecutorV2.Contract.Version(&_SuperExecutorV2.CallOpts)
}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() pure returns(string)
func (_SuperExecutorV2 *SuperExecutorV2CallerSession) Version() (string, error) {
	return _SuperExecutorV2.Contract.Version(&_SuperExecutorV2.CallOpts)
}

// Execute is a paid mutator transaction binding the contract method 0x1cff79cd.
//
// Solidity: function execute(address account, bytes data) returns()
func (_SuperExecutorV2 *SuperExecutorV2Transactor) Execute(opts *bind.TransactOpts, account common.Address, data []byte) (*types.Transaction, error) {
	return _SuperExecutorV2.contract.Transact(opts, "execute", account, data)
}

// Execute is a paid mutator transaction binding the contract method 0x1cff79cd.
//
// Solidity: function execute(address account, bytes data) returns()
func (_SuperExecutorV2 *SuperExecutorV2Session) Execute(account common.Address, data []byte) (*types.Transaction, error) {
	return _SuperExecutorV2.Contract.Execute(&_SuperExecutorV2.TransactOpts, account, data)
}

// Execute is a paid mutator transaction binding the contract method 0x1cff79cd.
//
// Solidity: function execute(address account, bytes data) returns()
func (_SuperExecutorV2 *SuperExecutorV2TransactorSession) Execute(account common.Address, data []byte) (*types.Transaction, error) {
	return _SuperExecutorV2.Contract.Execute(&_SuperExecutorV2.TransactOpts, account, data)
}

// ExecuteFromGateway is a paid mutator transaction binding the contract method 0x17429edd.
//
// Solidity: function executeFromGateway(address account, bytes data) returns()
func (_SuperExecutorV2 *SuperExecutorV2Transactor) ExecuteFromGateway(opts *bind.TransactOpts, account common.Address, data []byte) (*types.Transaction, error) {
	return _SuperExecutorV2.contract.Transact(opts, "executeFromGateway", account, data)
}

// ExecuteFromGateway is a paid mutator transaction binding the contract method 0x17429edd.
//
// Solidity: function executeFromGateway(address account, bytes data) returns()
func (_SuperExecutorV2 *SuperExecutorV2Session) ExecuteFromGateway(account common.Address, data []byte) (*types.Transaction, error) {
	return _SuperExecutorV2.Contract.ExecuteFromGateway(&_SuperExecutorV2.TransactOpts, account, data)
}

// ExecuteFromGateway is a paid mutator transaction binding the contract method 0x17429edd.
//
// Solidity: function executeFromGateway(address account, bytes data) returns()
func (_SuperExecutorV2 *SuperExecutorV2TransactorSession) ExecuteFromGateway(account common.Address, data []byte) (*types.Transaction, error) {
	return _SuperExecutorV2.Contract.ExecuteFromGateway(&_SuperExecutorV2.TransactOpts, account, data)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_SuperExecutorV2 *SuperExecutorV2Transactor) OnInstall(opts *bind.TransactOpts, arg0 []byte) (*types.Transaction, error) {
	return _SuperExecutorV2.contract.Transact(opts, "onInstall", arg0)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_SuperExecutorV2 *SuperExecutorV2Session) OnInstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperExecutorV2.Contract.OnInstall(&_SuperExecutorV2.TransactOpts, arg0)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_SuperExecutorV2 *SuperExecutorV2TransactorSession) OnInstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperExecutorV2.Contract.OnInstall(&_SuperExecutorV2.TransactOpts, arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperExecutorV2 *SuperExecutorV2Transactor) OnUninstall(opts *bind.TransactOpts, arg0 []byte) (*types.Transaction, error) {
	return _SuperExecutorV2.contract.Transact(opts, "onUninstall", arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperExecutorV2 *SuperExecutorV2Session) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperExecutorV2.Contract.OnUninstall(&_SuperExecutorV2.TransactOpts, arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperExecutorV2 *SuperExecutorV2TransactorSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperExecutorV2.Contract.OnUninstall(&_SuperExecutorV2.TransactOpts, arg0)
}
