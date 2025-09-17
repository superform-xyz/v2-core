// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperSenderCreator

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

// SuperSenderCreatorMetaData contains all meta data concerning the SuperSenderCreator contract.
var SuperSenderCreatorMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"createSender\",\"inputs\":[{\"name\":\"initCode\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"sender\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"}]",
}

// SuperSenderCreatorABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperSenderCreatorMetaData.ABI instead.
var SuperSenderCreatorABI = SuperSenderCreatorMetaData.ABI

// SuperSenderCreator is an auto generated Go binding around an Ethereum contract.
type SuperSenderCreator struct {
	SuperSenderCreatorCaller     // Read-only binding to the contract
	SuperSenderCreatorTransactor // Write-only binding to the contract
	SuperSenderCreatorFilterer   // Log filterer for contract events
}

// SuperSenderCreatorCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperSenderCreatorCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperSenderCreatorTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperSenderCreatorTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperSenderCreatorFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperSenderCreatorFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperSenderCreatorSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperSenderCreatorSession struct {
	Contract     *SuperSenderCreator // Generic contract binding to set the session for
	CallOpts     bind.CallOpts       // Call options to use throughout this session
	TransactOpts bind.TransactOpts   // Transaction auth options to use throughout this session
}

// SuperSenderCreatorCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperSenderCreatorCallerSession struct {
	Contract *SuperSenderCreatorCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts             // Call options to use throughout this session
}

// SuperSenderCreatorTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperSenderCreatorTransactorSession struct {
	Contract     *SuperSenderCreatorTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts             // Transaction auth options to use throughout this session
}

// SuperSenderCreatorRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperSenderCreatorRaw struct {
	Contract *SuperSenderCreator // Generic contract binding to access the raw methods on
}

// SuperSenderCreatorCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperSenderCreatorCallerRaw struct {
	Contract *SuperSenderCreatorCaller // Generic read-only contract binding to access the raw methods on
}

// SuperSenderCreatorTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperSenderCreatorTransactorRaw struct {
	Contract *SuperSenderCreatorTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperSenderCreator creates a new instance of SuperSenderCreator, bound to a specific deployed contract.
func NewSuperSenderCreator(address common.Address, backend bind.ContractBackend) (*SuperSenderCreator, error) {
	contract, err := bindSuperSenderCreator(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperSenderCreator{SuperSenderCreatorCaller: SuperSenderCreatorCaller{contract: contract}, SuperSenderCreatorTransactor: SuperSenderCreatorTransactor{contract: contract}, SuperSenderCreatorFilterer: SuperSenderCreatorFilterer{contract: contract}}, nil
}

// NewSuperSenderCreatorCaller creates a new read-only instance of SuperSenderCreator, bound to a specific deployed contract.
func NewSuperSenderCreatorCaller(address common.Address, caller bind.ContractCaller) (*SuperSenderCreatorCaller, error) {
	contract, err := bindSuperSenderCreator(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperSenderCreatorCaller{contract: contract}, nil
}

// NewSuperSenderCreatorTransactor creates a new write-only instance of SuperSenderCreator, bound to a specific deployed contract.
func NewSuperSenderCreatorTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperSenderCreatorTransactor, error) {
	contract, err := bindSuperSenderCreator(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperSenderCreatorTransactor{contract: contract}, nil
}

// NewSuperSenderCreatorFilterer creates a new log filterer instance of SuperSenderCreator, bound to a specific deployed contract.
func NewSuperSenderCreatorFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperSenderCreatorFilterer, error) {
	contract, err := bindSuperSenderCreator(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperSenderCreatorFilterer{contract: contract}, nil
}

// bindSuperSenderCreator binds a generic wrapper to an already deployed contract.
func bindSuperSenderCreator(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperSenderCreatorMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperSenderCreator *SuperSenderCreatorRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperSenderCreator.Contract.SuperSenderCreatorCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperSenderCreator *SuperSenderCreatorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperSenderCreator.Contract.SuperSenderCreatorTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperSenderCreator *SuperSenderCreatorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperSenderCreator.Contract.SuperSenderCreatorTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperSenderCreator *SuperSenderCreatorCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperSenderCreator.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperSenderCreator *SuperSenderCreatorTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperSenderCreator.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperSenderCreator *SuperSenderCreatorTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperSenderCreator.Contract.contract.Transact(opts, method, params...)
}

// CreateSender is a paid mutator transaction binding the contract method 0x570e1a36.
//
// Solidity: function createSender(bytes initCode) returns(address sender)
func (_SuperSenderCreator *SuperSenderCreatorTransactor) CreateSender(opts *bind.TransactOpts, initCode []byte) (*types.Transaction, error) {
	return _SuperSenderCreator.contract.Transact(opts, "createSender", initCode)
}

// CreateSender is a paid mutator transaction binding the contract method 0x570e1a36.
//
// Solidity: function createSender(bytes initCode) returns(address sender)
func (_SuperSenderCreator *SuperSenderCreatorSession) CreateSender(initCode []byte) (*types.Transaction, error) {
	return _SuperSenderCreator.Contract.CreateSender(&_SuperSenderCreator.TransactOpts, initCode)
}

// CreateSender is a paid mutator transaction binding the contract method 0x570e1a36.
//
// Solidity: function createSender(bytes initCode) returns(address sender)
func (_SuperSenderCreator *SuperSenderCreatorTransactorSession) CreateSender(initCode []byte) (*types.Transaction, error) {
	return _SuperSenderCreator.Contract.CreateSender(&_SuperSenderCreator.TransactOpts, initCode)
}
