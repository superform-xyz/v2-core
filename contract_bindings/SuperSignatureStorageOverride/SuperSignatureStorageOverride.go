// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperSignatureStorageOverride

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

// SuperSignatureStorageOverrideMetaData contains all meta data concerning the SuperSignatureStorageOverride contract.
var SuperSignatureStorageOverrideMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"retrieveSignatureData\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"storeSignatureData\",\"inputs\":[{\"name\":\"signature\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"error\",\"name\":\"INVALID_USER_OP\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_USER_OP\",\"inputs\":[]}]",
}

// SuperSignatureStorageOverrideABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperSignatureStorageOverrideMetaData.ABI instead.
var SuperSignatureStorageOverrideABI = SuperSignatureStorageOverrideMetaData.ABI

// SuperSignatureStorageOverride is an auto generated Go binding around an Ethereum contract.
type SuperSignatureStorageOverride struct {
	SuperSignatureStorageOverrideCaller     // Read-only binding to the contract
	SuperSignatureStorageOverrideTransactor // Write-only binding to the contract
	SuperSignatureStorageOverrideFilterer   // Log filterer for contract events
}

// SuperSignatureStorageOverrideCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperSignatureStorageOverrideCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperSignatureStorageOverrideTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperSignatureStorageOverrideTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperSignatureStorageOverrideFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperSignatureStorageOverrideFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperSignatureStorageOverrideSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperSignatureStorageOverrideSession struct {
	Contract     *SuperSignatureStorageOverride // Generic contract binding to set the session for
	CallOpts     bind.CallOpts                  // Call options to use throughout this session
	TransactOpts bind.TransactOpts              // Transaction auth options to use throughout this session
}

// SuperSignatureStorageOverrideCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperSignatureStorageOverrideCallerSession struct {
	Contract *SuperSignatureStorageOverrideCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                        // Call options to use throughout this session
}

// SuperSignatureStorageOverrideTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperSignatureStorageOverrideTransactorSession struct {
	Contract     *SuperSignatureStorageOverrideTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                        // Transaction auth options to use throughout this session
}

// SuperSignatureStorageOverrideRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperSignatureStorageOverrideRaw struct {
	Contract *SuperSignatureStorageOverride // Generic contract binding to access the raw methods on
}

// SuperSignatureStorageOverrideCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperSignatureStorageOverrideCallerRaw struct {
	Contract *SuperSignatureStorageOverrideCaller // Generic read-only contract binding to access the raw methods on
}

// SuperSignatureStorageOverrideTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperSignatureStorageOverrideTransactorRaw struct {
	Contract *SuperSignatureStorageOverrideTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperSignatureStorageOverride creates a new instance of SuperSignatureStorageOverride, bound to a specific deployed contract.
func NewSuperSignatureStorageOverride(address common.Address, backend bind.ContractBackend) (*SuperSignatureStorageOverride, error) {
	contract, err := bindSuperSignatureStorageOverride(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperSignatureStorageOverride{SuperSignatureStorageOverrideCaller: SuperSignatureStorageOverrideCaller{contract: contract}, SuperSignatureStorageOverrideTransactor: SuperSignatureStorageOverrideTransactor{contract: contract}, SuperSignatureStorageOverrideFilterer: SuperSignatureStorageOverrideFilterer{contract: contract}}, nil
}

// NewSuperSignatureStorageOverrideCaller creates a new read-only instance of SuperSignatureStorageOverride, bound to a specific deployed contract.
func NewSuperSignatureStorageOverrideCaller(address common.Address, caller bind.ContractCaller) (*SuperSignatureStorageOverrideCaller, error) {
	contract, err := bindSuperSignatureStorageOverride(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperSignatureStorageOverrideCaller{contract: contract}, nil
}

// NewSuperSignatureStorageOverrideTransactor creates a new write-only instance of SuperSignatureStorageOverride, bound to a specific deployed contract.
func NewSuperSignatureStorageOverrideTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperSignatureStorageOverrideTransactor, error) {
	contract, err := bindSuperSignatureStorageOverride(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperSignatureStorageOverrideTransactor{contract: contract}, nil
}

// NewSuperSignatureStorageOverrideFilterer creates a new log filterer instance of SuperSignatureStorageOverride, bound to a specific deployed contract.
func NewSuperSignatureStorageOverrideFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperSignatureStorageOverrideFilterer, error) {
	contract, err := bindSuperSignatureStorageOverride(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperSignatureStorageOverrideFilterer{contract: contract}, nil
}

// bindSuperSignatureStorageOverride binds a generic wrapper to an already deployed contract.
func bindSuperSignatureStorageOverride(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperSignatureStorageOverrideMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperSignatureStorageOverride *SuperSignatureStorageOverrideRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperSignatureStorageOverride.Contract.SuperSignatureStorageOverrideCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperSignatureStorageOverride *SuperSignatureStorageOverrideRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperSignatureStorageOverride.Contract.SuperSignatureStorageOverrideTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperSignatureStorageOverride *SuperSignatureStorageOverrideRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperSignatureStorageOverride.Contract.SuperSignatureStorageOverrideTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperSignatureStorageOverride *SuperSignatureStorageOverrideCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperSignatureStorageOverride.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperSignatureStorageOverride *SuperSignatureStorageOverrideTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperSignatureStorageOverride.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperSignatureStorageOverride *SuperSignatureStorageOverrideTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperSignatureStorageOverride.Contract.contract.Transact(opts, method, params...)
}

// RetrieveSignatureData is a free data retrieval call binding the contract method 0x0f65bac5.
//
// Solidity: function retrieveSignatureData(address account) view returns(bytes)
func (_SuperSignatureStorageOverride *SuperSignatureStorageOverrideCaller) RetrieveSignatureData(opts *bind.CallOpts, account common.Address) ([]byte, error) {
	var out []interface{}
	err := _SuperSignatureStorageOverride.contract.Call(opts, &out, "retrieveSignatureData", account)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// RetrieveSignatureData is a free data retrieval call binding the contract method 0x0f65bac5.
//
// Solidity: function retrieveSignatureData(address account) view returns(bytes)
func (_SuperSignatureStorageOverride *SuperSignatureStorageOverrideSession) RetrieveSignatureData(account common.Address) ([]byte, error) {
	return _SuperSignatureStorageOverride.Contract.RetrieveSignatureData(&_SuperSignatureStorageOverride.CallOpts, account)
}

// RetrieveSignatureData is a free data retrieval call binding the contract method 0x0f65bac5.
//
// Solidity: function retrieveSignatureData(address account) view returns(bytes)
func (_SuperSignatureStorageOverride *SuperSignatureStorageOverrideCallerSession) RetrieveSignatureData(account common.Address) ([]byte, error) {
	return _SuperSignatureStorageOverride.Contract.RetrieveSignatureData(&_SuperSignatureStorageOverride.CallOpts, account)
}

// StoreSignatureData is a paid mutator transaction binding the contract method 0x5fa0bd2a.
//
// Solidity: function storeSignatureData(bytes signature, address account) returns()
func (_SuperSignatureStorageOverride *SuperSignatureStorageOverrideTransactor) StoreSignatureData(opts *bind.TransactOpts, signature []byte, account common.Address) (*types.Transaction, error) {
	return _SuperSignatureStorageOverride.contract.Transact(opts, "storeSignatureData", signature, account)
}

// StoreSignatureData is a paid mutator transaction binding the contract method 0x5fa0bd2a.
//
// Solidity: function storeSignatureData(bytes signature, address account) returns()
func (_SuperSignatureStorageOverride *SuperSignatureStorageOverrideSession) StoreSignatureData(signature []byte, account common.Address) (*types.Transaction, error) {
	return _SuperSignatureStorageOverride.Contract.StoreSignatureData(&_SuperSignatureStorageOverride.TransactOpts, signature, account)
}

// StoreSignatureData is a paid mutator transaction binding the contract method 0x5fa0bd2a.
//
// Solidity: function storeSignatureData(bytes signature, address account) returns()
func (_SuperSignatureStorageOverride *SuperSignatureStorageOverrideTransactorSession) StoreSignatureData(signature []byte, account common.Address) (*types.Transaction, error) {
	return _SuperSignatureStorageOverride.Contract.StoreSignatureData(&_SuperSignatureStorageOverride.TransactOpts, signature, account)
}
