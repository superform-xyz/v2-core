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

// ISuperExecutorMetaData contains all meta data concerning the ISuperExecutor contract.
var ISuperExecutorMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"execute\",\"inputs\":[{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"executeFromGateway\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"error\",\"name\":\"ALREADY_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_AUTHORIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_INITIALIZED\",\"inputs\":[]}]",
}

// ISuperExecutorABI is the input ABI used to generate the binding from.
// Deprecated: Use ISuperExecutorMetaData.ABI instead.
var ISuperExecutorABI = ISuperExecutorMetaData.ABI

// ISuperExecutor is an auto generated Go binding around an Ethereum contract.
type ISuperExecutor struct {
	ISuperExecutorCaller     // Read-only binding to the contract
	ISuperExecutorTransactor // Write-only binding to the contract
	ISuperExecutorFilterer   // Log filterer for contract events
}

// ISuperExecutorCaller is an auto generated read-only Go binding around an Ethereum contract.
type ISuperExecutorCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ISuperExecutorTransactor is an auto generated write-only Go binding around an Ethereum contract.
type ISuperExecutorTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ISuperExecutorFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type ISuperExecutorFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ISuperExecutorSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type ISuperExecutorSession struct {
	Contract     *ISuperExecutor   // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// ISuperExecutorCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type ISuperExecutorCallerSession struct {
	Contract *ISuperExecutorCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts         // Call options to use throughout this session
}

// ISuperExecutorTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type ISuperExecutorTransactorSession struct {
	Contract     *ISuperExecutorTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts         // Transaction auth options to use throughout this session
}

// ISuperExecutorRaw is an auto generated low-level Go binding around an Ethereum contract.
type ISuperExecutorRaw struct {
	Contract *ISuperExecutor // Generic contract binding to access the raw methods on
}

// ISuperExecutorCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type ISuperExecutorCallerRaw struct {
	Contract *ISuperExecutorCaller // Generic read-only contract binding to access the raw methods on
}

// ISuperExecutorTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type ISuperExecutorTransactorRaw struct {
	Contract *ISuperExecutorTransactor // Generic write-only contract binding to access the raw methods on
}

// NewISuperExecutor creates a new instance of ISuperExecutor, bound to a specific deployed contract.
func NewISuperExecutor(address common.Address, backend bind.ContractBackend) (*ISuperExecutor, error) {
	contract, err := bindISuperExecutor(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &ISuperExecutor{ISuperExecutorCaller: ISuperExecutorCaller{contract: contract}, ISuperExecutorTransactor: ISuperExecutorTransactor{contract: contract}, ISuperExecutorFilterer: ISuperExecutorFilterer{contract: contract}}, nil
}

// NewISuperExecutorCaller creates a new read-only instance of ISuperExecutor, bound to a specific deployed contract.
func NewISuperExecutorCaller(address common.Address, caller bind.ContractCaller) (*ISuperExecutorCaller, error) {
	contract, err := bindISuperExecutor(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &ISuperExecutorCaller{contract: contract}, nil
}

// NewISuperExecutorTransactor creates a new write-only instance of ISuperExecutor, bound to a specific deployed contract.
func NewISuperExecutorTransactor(address common.Address, transactor bind.ContractTransactor) (*ISuperExecutorTransactor, error) {
	contract, err := bindISuperExecutor(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &ISuperExecutorTransactor{contract: contract}, nil
}

// NewISuperExecutorFilterer creates a new log filterer instance of ISuperExecutor, bound to a specific deployed contract.
func NewISuperExecutorFilterer(address common.Address, filterer bind.ContractFilterer) (*ISuperExecutorFilterer, error) {
	contract, err := bindISuperExecutor(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &ISuperExecutorFilterer{contract: contract}, nil
}

// bindISuperExecutor binds a generic wrapper to an already deployed contract.
func bindISuperExecutor(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := ISuperExecutorMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ISuperExecutor *ISuperExecutorRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ISuperExecutor.Contract.ISuperExecutorCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ISuperExecutor *ISuperExecutorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ISuperExecutor.Contract.ISuperExecutorTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ISuperExecutor *ISuperExecutorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ISuperExecutor.Contract.ISuperExecutorTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ISuperExecutor *ISuperExecutorCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ISuperExecutor.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ISuperExecutor *ISuperExecutorTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ISuperExecutor.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ISuperExecutor *ISuperExecutorTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ISuperExecutor.Contract.contract.Transact(opts, method, params...)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_ISuperExecutor *ISuperExecutorTransactor) Execute(opts *bind.TransactOpts, data []byte) (*types.Transaction, error) {
	return _ISuperExecutor.contract.Transact(opts, "execute", data)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_ISuperExecutor *ISuperExecutorSession) Execute(data []byte) (*types.Transaction, error) {
	return _ISuperExecutor.Contract.Execute(&_ISuperExecutor.TransactOpts, data)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_ISuperExecutor *ISuperExecutorTransactorSession) Execute(data []byte) (*types.Transaction, error) {
	return _ISuperExecutor.Contract.Execute(&_ISuperExecutor.TransactOpts, data)
}

// ExecuteFromGateway is a paid mutator transaction binding the contract method 0x17429edd.
//
// Solidity: function executeFromGateway(address account, bytes data) returns()
func (_ISuperExecutor *ISuperExecutorTransactor) ExecuteFromGateway(opts *bind.TransactOpts, account common.Address, data []byte) (*types.Transaction, error) {
	return _ISuperExecutor.contract.Transact(opts, "executeFromGateway", account, data)
}

// ExecuteFromGateway is a paid mutator transaction binding the contract method 0x17429edd.
//
// Solidity: function executeFromGateway(address account, bytes data) returns()
func (_ISuperExecutor *ISuperExecutorSession) ExecuteFromGateway(account common.Address, data []byte) (*types.Transaction, error) {
	return _ISuperExecutor.Contract.ExecuteFromGateway(&_ISuperExecutor.TransactOpts, account, data)
}

// ExecuteFromGateway is a paid mutator transaction binding the contract method 0x17429edd.
//
// Solidity: function executeFromGateway(address account, bytes data) returns()
func (_ISuperExecutor *ISuperExecutorTransactorSession) ExecuteFromGateway(account common.Address, data []byte) (*types.Transaction, error) {
	return _ISuperExecutor.Contract.ExecuteFromGateway(&_ISuperExecutor.TransactOpts, account, data)
}
