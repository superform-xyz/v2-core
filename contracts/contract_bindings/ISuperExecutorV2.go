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

// ISuperExecutorV2MetaData contains all meta data concerning the ISuperExecutorV2 contract.
var ISuperExecutorV2MetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"execute\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"executeFromGateway\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"superActions\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AMOUNT_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"DATA_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_AUTHORIZED\",\"inputs\":[]}]",
}

// ISuperExecutorV2ABI is the input ABI used to generate the binding from.
// Deprecated: Use ISuperExecutorV2MetaData.ABI instead.
var ISuperExecutorV2ABI = ISuperExecutorV2MetaData.ABI

// ISuperExecutorV2 is an auto generated Go binding around an Ethereum contract.
type ISuperExecutorV2 struct {
	ISuperExecutorV2Caller     // Read-only binding to the contract
	ISuperExecutorV2Transactor // Write-only binding to the contract
	ISuperExecutorV2Filterer   // Log filterer for contract events
}

// ISuperExecutorV2Caller is an auto generated read-only Go binding around an Ethereum contract.
type ISuperExecutorV2Caller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ISuperExecutorV2Transactor is an auto generated write-only Go binding around an Ethereum contract.
type ISuperExecutorV2Transactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ISuperExecutorV2Filterer is an auto generated log filtering Go binding around an Ethereum contract events.
type ISuperExecutorV2Filterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ISuperExecutorV2Session is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type ISuperExecutorV2Session struct {
	Contract     *ISuperExecutorV2 // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// ISuperExecutorV2CallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type ISuperExecutorV2CallerSession struct {
	Contract *ISuperExecutorV2Caller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts           // Call options to use throughout this session
}

// ISuperExecutorV2TransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type ISuperExecutorV2TransactorSession struct {
	Contract     *ISuperExecutorV2Transactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts           // Transaction auth options to use throughout this session
}

// ISuperExecutorV2Raw is an auto generated low-level Go binding around an Ethereum contract.
type ISuperExecutorV2Raw struct {
	Contract *ISuperExecutorV2 // Generic contract binding to access the raw methods on
}

// ISuperExecutorV2CallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type ISuperExecutorV2CallerRaw struct {
	Contract *ISuperExecutorV2Caller // Generic read-only contract binding to access the raw methods on
}

// ISuperExecutorV2TransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type ISuperExecutorV2TransactorRaw struct {
	Contract *ISuperExecutorV2Transactor // Generic write-only contract binding to access the raw methods on
}

// NewISuperExecutorV2 creates a new instance of ISuperExecutorV2, bound to a specific deployed contract.
func NewISuperExecutorV2(address common.Address, backend bind.ContractBackend) (*ISuperExecutorV2, error) {
	contract, err := bindISuperExecutorV2(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &ISuperExecutorV2{ISuperExecutorV2Caller: ISuperExecutorV2Caller{contract: contract}, ISuperExecutorV2Transactor: ISuperExecutorV2Transactor{contract: contract}, ISuperExecutorV2Filterer: ISuperExecutorV2Filterer{contract: contract}}, nil
}

// NewISuperExecutorV2Caller creates a new read-only instance of ISuperExecutorV2, bound to a specific deployed contract.
func NewISuperExecutorV2Caller(address common.Address, caller bind.ContractCaller) (*ISuperExecutorV2Caller, error) {
	contract, err := bindISuperExecutorV2(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &ISuperExecutorV2Caller{contract: contract}, nil
}

// NewISuperExecutorV2Transactor creates a new write-only instance of ISuperExecutorV2, bound to a specific deployed contract.
func NewISuperExecutorV2Transactor(address common.Address, transactor bind.ContractTransactor) (*ISuperExecutorV2Transactor, error) {
	contract, err := bindISuperExecutorV2(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &ISuperExecutorV2Transactor{contract: contract}, nil
}

// NewISuperExecutorV2Filterer creates a new log filterer instance of ISuperExecutorV2, bound to a specific deployed contract.
func NewISuperExecutorV2Filterer(address common.Address, filterer bind.ContractFilterer) (*ISuperExecutorV2Filterer, error) {
	contract, err := bindISuperExecutorV2(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &ISuperExecutorV2Filterer{contract: contract}, nil
}

// bindISuperExecutorV2 binds a generic wrapper to an already deployed contract.
func bindISuperExecutorV2(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := ISuperExecutorV2MetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ISuperExecutorV2 *ISuperExecutorV2Raw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ISuperExecutorV2.Contract.ISuperExecutorV2Caller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ISuperExecutorV2 *ISuperExecutorV2Raw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ISuperExecutorV2.Contract.ISuperExecutorV2Transactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ISuperExecutorV2 *ISuperExecutorV2Raw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ISuperExecutorV2.Contract.ISuperExecutorV2Transactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ISuperExecutorV2 *ISuperExecutorV2CallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ISuperExecutorV2.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ISuperExecutorV2 *ISuperExecutorV2TransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ISuperExecutorV2.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ISuperExecutorV2 *ISuperExecutorV2TransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ISuperExecutorV2.Contract.contract.Transact(opts, method, params...)
}

// SuperActions is a free data retrieval call binding the contract method 0x40e98cf6.
//
// Solidity: function superActions() view returns(address)
func (_ISuperExecutorV2 *ISuperExecutorV2Caller) SuperActions(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ISuperExecutorV2.contract.Call(opts, &out, "superActions")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SuperActions is a free data retrieval call binding the contract method 0x40e98cf6.
//
// Solidity: function superActions() view returns(address)
func (_ISuperExecutorV2 *ISuperExecutorV2Session) SuperActions() (common.Address, error) {
	return _ISuperExecutorV2.Contract.SuperActions(&_ISuperExecutorV2.CallOpts)
}

// SuperActions is a free data retrieval call binding the contract method 0x40e98cf6.
//
// Solidity: function superActions() view returns(address)
func (_ISuperExecutorV2 *ISuperExecutorV2CallerSession) SuperActions() (common.Address, error) {
	return _ISuperExecutorV2.Contract.SuperActions(&_ISuperExecutorV2.CallOpts)
}

// Execute is a paid mutator transaction binding the contract method 0x1cff79cd.
//
// Solidity: function execute(address account, bytes data) returns()
func (_ISuperExecutorV2 *ISuperExecutorV2Transactor) Execute(opts *bind.TransactOpts, account common.Address, data []byte) (*types.Transaction, error) {
	return _ISuperExecutorV2.contract.Transact(opts, "execute", account, data)
}

// Execute is a paid mutator transaction binding the contract method 0x1cff79cd.
//
// Solidity: function execute(address account, bytes data) returns()
func (_ISuperExecutorV2 *ISuperExecutorV2Session) Execute(account common.Address, data []byte) (*types.Transaction, error) {
	return _ISuperExecutorV2.Contract.Execute(&_ISuperExecutorV2.TransactOpts, account, data)
}

// Execute is a paid mutator transaction binding the contract method 0x1cff79cd.
//
// Solidity: function execute(address account, bytes data) returns()
func (_ISuperExecutorV2 *ISuperExecutorV2TransactorSession) Execute(account common.Address, data []byte) (*types.Transaction, error) {
	return _ISuperExecutorV2.Contract.Execute(&_ISuperExecutorV2.TransactOpts, account, data)
}

// ExecuteFromGateway is a paid mutator transaction binding the contract method 0x17429edd.
//
// Solidity: function executeFromGateway(address account, bytes data) returns()
func (_ISuperExecutorV2 *ISuperExecutorV2Transactor) ExecuteFromGateway(opts *bind.TransactOpts, account common.Address, data []byte) (*types.Transaction, error) {
	return _ISuperExecutorV2.contract.Transact(opts, "executeFromGateway", account, data)
}

// ExecuteFromGateway is a paid mutator transaction binding the contract method 0x17429edd.
//
// Solidity: function executeFromGateway(address account, bytes data) returns()
func (_ISuperExecutorV2 *ISuperExecutorV2Session) ExecuteFromGateway(account common.Address, data []byte) (*types.Transaction, error) {
	return _ISuperExecutorV2.Contract.ExecuteFromGateway(&_ISuperExecutorV2.TransactOpts, account, data)
}

// ExecuteFromGateway is a paid mutator transaction binding the contract method 0x17429edd.
//
// Solidity: function executeFromGateway(address account, bytes data) returns()
func (_ISuperExecutorV2 *ISuperExecutorV2TransactorSession) ExecuteFromGateway(account common.Address, data []byte) (*types.Transaction, error) {
	return _ISuperExecutorV2.Contract.ExecuteFromGateway(&_ISuperExecutorV2.TransactOpts, account, data)
}
