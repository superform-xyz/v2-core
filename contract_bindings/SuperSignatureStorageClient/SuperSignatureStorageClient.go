// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperSignatureStorageClient

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

// SuperSignatureStorageClientMetaData contains all meta data concerning the SuperSignatureStorageClient contract.
var SuperSignatureStorageClientMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"storeAndRetrieveSignature\",\"inputs\":[{\"name\":\"storageContract\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"sigData\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"nonpayable\"}]",
}

// SuperSignatureStorageClientABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperSignatureStorageClientMetaData.ABI instead.
var SuperSignatureStorageClientABI = SuperSignatureStorageClientMetaData.ABI

// SuperSignatureStorageClient is an auto generated Go binding around an Ethereum contract.
type SuperSignatureStorageClient struct {
	SuperSignatureStorageClientCaller     // Read-only binding to the contract
	SuperSignatureStorageClientTransactor // Write-only binding to the contract
	SuperSignatureStorageClientFilterer   // Log filterer for contract events
}

// SuperSignatureStorageClientCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperSignatureStorageClientCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperSignatureStorageClientTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperSignatureStorageClientTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperSignatureStorageClientFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperSignatureStorageClientFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperSignatureStorageClientSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperSignatureStorageClientSession struct {
	Contract     *SuperSignatureStorageClient // Generic contract binding to set the session for
	CallOpts     bind.CallOpts                // Call options to use throughout this session
	TransactOpts bind.TransactOpts            // Transaction auth options to use throughout this session
}

// SuperSignatureStorageClientCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperSignatureStorageClientCallerSession struct {
	Contract *SuperSignatureStorageClientCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                      // Call options to use throughout this session
}

// SuperSignatureStorageClientTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperSignatureStorageClientTransactorSession struct {
	Contract     *SuperSignatureStorageClientTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                      // Transaction auth options to use throughout this session
}

// SuperSignatureStorageClientRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperSignatureStorageClientRaw struct {
	Contract *SuperSignatureStorageClient // Generic contract binding to access the raw methods on
}

// SuperSignatureStorageClientCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperSignatureStorageClientCallerRaw struct {
	Contract *SuperSignatureStorageClientCaller // Generic read-only contract binding to access the raw methods on
}

// SuperSignatureStorageClientTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperSignatureStorageClientTransactorRaw struct {
	Contract *SuperSignatureStorageClientTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperSignatureStorageClient creates a new instance of SuperSignatureStorageClient, bound to a specific deployed contract.
func NewSuperSignatureStorageClient(address common.Address, backend bind.ContractBackend) (*SuperSignatureStorageClient, error) {
	contract, err := bindSuperSignatureStorageClient(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperSignatureStorageClient{SuperSignatureStorageClientCaller: SuperSignatureStorageClientCaller{contract: contract}, SuperSignatureStorageClientTransactor: SuperSignatureStorageClientTransactor{contract: contract}, SuperSignatureStorageClientFilterer: SuperSignatureStorageClientFilterer{contract: contract}}, nil
}

// NewSuperSignatureStorageClientCaller creates a new read-only instance of SuperSignatureStorageClient, bound to a specific deployed contract.
func NewSuperSignatureStorageClientCaller(address common.Address, caller bind.ContractCaller) (*SuperSignatureStorageClientCaller, error) {
	contract, err := bindSuperSignatureStorageClient(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperSignatureStorageClientCaller{contract: contract}, nil
}

// NewSuperSignatureStorageClientTransactor creates a new write-only instance of SuperSignatureStorageClient, bound to a specific deployed contract.
func NewSuperSignatureStorageClientTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperSignatureStorageClientTransactor, error) {
	contract, err := bindSuperSignatureStorageClient(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperSignatureStorageClientTransactor{contract: contract}, nil
}

// NewSuperSignatureStorageClientFilterer creates a new log filterer instance of SuperSignatureStorageClient, bound to a specific deployed contract.
func NewSuperSignatureStorageClientFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperSignatureStorageClientFilterer, error) {
	contract, err := bindSuperSignatureStorageClient(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperSignatureStorageClientFilterer{contract: contract}, nil
}

// bindSuperSignatureStorageClient binds a generic wrapper to an already deployed contract.
func bindSuperSignatureStorageClient(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperSignatureStorageClientMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperSignatureStorageClient *SuperSignatureStorageClientRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperSignatureStorageClient.Contract.SuperSignatureStorageClientCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperSignatureStorageClient *SuperSignatureStorageClientRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperSignatureStorageClient.Contract.SuperSignatureStorageClientTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperSignatureStorageClient *SuperSignatureStorageClientRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperSignatureStorageClient.Contract.SuperSignatureStorageClientTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperSignatureStorageClient *SuperSignatureStorageClientCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperSignatureStorageClient.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperSignatureStorageClient *SuperSignatureStorageClientTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperSignatureStorageClient.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperSignatureStorageClient *SuperSignatureStorageClientTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperSignatureStorageClient.Contract.contract.Transact(opts, method, params...)
}

// StoreAndRetrieveSignature is a paid mutator transaction binding the contract method 0x3e0f53d8.
//
// Solidity: function storeAndRetrieveSignature(address storageContract, bytes sigData, address account) returns(bytes)
func (_SuperSignatureStorageClient *SuperSignatureStorageClientTransactor) StoreAndRetrieveSignature(opts *bind.TransactOpts, storageContract common.Address, sigData []byte, account common.Address) (*types.Transaction, error) {
	return _SuperSignatureStorageClient.contract.Transact(opts, "storeAndRetrieveSignature", storageContract, sigData, account)
}

// StoreAndRetrieveSignature is a paid mutator transaction binding the contract method 0x3e0f53d8.
//
// Solidity: function storeAndRetrieveSignature(address storageContract, bytes sigData, address account) returns(bytes)
func (_SuperSignatureStorageClient *SuperSignatureStorageClientSession) StoreAndRetrieveSignature(storageContract common.Address, sigData []byte, account common.Address) (*types.Transaction, error) {
	return _SuperSignatureStorageClient.Contract.StoreAndRetrieveSignature(&_SuperSignatureStorageClient.TransactOpts, storageContract, sigData, account)
}

// StoreAndRetrieveSignature is a paid mutator transaction binding the contract method 0x3e0f53d8.
//
// Solidity: function storeAndRetrieveSignature(address storageContract, bytes sigData, address account) returns(bytes)
func (_SuperSignatureStorageClient *SuperSignatureStorageClientTransactorSession) StoreAndRetrieveSignature(storageContract common.Address, sigData []byte, account common.Address) (*types.Transaction, error) {
	return _SuperSignatureStorageClient.Contract.StoreAndRetrieveSignature(&_SuperSignatureStorageClient.TransactOpts, storageContract, sigData, account)
}
