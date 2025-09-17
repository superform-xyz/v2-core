// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperValidatorSimulations

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

// SuperValidatorSimulationsMetaData contains all meta data concerning the SuperValidatorSimulations contract.
var SuperValidatorSimulationsMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"retrieveSignatureData\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"storeSignatureData\",\"inputs\":[{\"name\":\"signature\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"error\",\"name\":\"INVALID_USER_OP\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_USER_OP\",\"inputs\":[]}]",
}

// SuperValidatorSimulationsABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperValidatorSimulationsMetaData.ABI instead.
var SuperValidatorSimulationsABI = SuperValidatorSimulationsMetaData.ABI

// SuperValidatorSimulations is an auto generated Go binding around an Ethereum contract.
type SuperValidatorSimulations struct {
	SuperValidatorSimulationsCaller     // Read-only binding to the contract
	SuperValidatorSimulationsTransactor // Write-only binding to the contract
	SuperValidatorSimulationsFilterer   // Log filterer for contract events
}

// SuperValidatorSimulationsCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperValidatorSimulationsCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperValidatorSimulationsTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperValidatorSimulationsTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperValidatorSimulationsFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperValidatorSimulationsFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperValidatorSimulationsSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperValidatorSimulationsSession struct {
	Contract     *SuperValidatorSimulations // Generic contract binding to set the session for
	CallOpts     bind.CallOpts              // Call options to use throughout this session
	TransactOpts bind.TransactOpts          // Transaction auth options to use throughout this session
}

// SuperValidatorSimulationsCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperValidatorSimulationsCallerSession struct {
	Contract *SuperValidatorSimulationsCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                    // Call options to use throughout this session
}

// SuperValidatorSimulationsTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperValidatorSimulationsTransactorSession struct {
	Contract     *SuperValidatorSimulationsTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                    // Transaction auth options to use throughout this session
}

// SuperValidatorSimulationsRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperValidatorSimulationsRaw struct {
	Contract *SuperValidatorSimulations // Generic contract binding to access the raw methods on
}

// SuperValidatorSimulationsCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperValidatorSimulationsCallerRaw struct {
	Contract *SuperValidatorSimulationsCaller // Generic read-only contract binding to access the raw methods on
}

// SuperValidatorSimulationsTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperValidatorSimulationsTransactorRaw struct {
	Contract *SuperValidatorSimulationsTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperValidatorSimulations creates a new instance of SuperValidatorSimulations, bound to a specific deployed contract.
func NewSuperValidatorSimulations(address common.Address, backend bind.ContractBackend) (*SuperValidatorSimulations, error) {
	contract, err := bindSuperValidatorSimulations(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperValidatorSimulations{SuperValidatorSimulationsCaller: SuperValidatorSimulationsCaller{contract: contract}, SuperValidatorSimulationsTransactor: SuperValidatorSimulationsTransactor{contract: contract}, SuperValidatorSimulationsFilterer: SuperValidatorSimulationsFilterer{contract: contract}}, nil
}

// NewSuperValidatorSimulationsCaller creates a new read-only instance of SuperValidatorSimulations, bound to a specific deployed contract.
func NewSuperValidatorSimulationsCaller(address common.Address, caller bind.ContractCaller) (*SuperValidatorSimulationsCaller, error) {
	contract, err := bindSuperValidatorSimulations(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperValidatorSimulationsCaller{contract: contract}, nil
}

// NewSuperValidatorSimulationsTransactor creates a new write-only instance of SuperValidatorSimulations, bound to a specific deployed contract.
func NewSuperValidatorSimulationsTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperValidatorSimulationsTransactor, error) {
	contract, err := bindSuperValidatorSimulations(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperValidatorSimulationsTransactor{contract: contract}, nil
}

// NewSuperValidatorSimulationsFilterer creates a new log filterer instance of SuperValidatorSimulations, bound to a specific deployed contract.
func NewSuperValidatorSimulationsFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperValidatorSimulationsFilterer, error) {
	contract, err := bindSuperValidatorSimulations(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperValidatorSimulationsFilterer{contract: contract}, nil
}

// bindSuperValidatorSimulations binds a generic wrapper to an already deployed contract.
func bindSuperValidatorSimulations(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperValidatorSimulationsMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperValidatorSimulations *SuperValidatorSimulationsRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperValidatorSimulations.Contract.SuperValidatorSimulationsCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperValidatorSimulations *SuperValidatorSimulationsRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperValidatorSimulations.Contract.SuperValidatorSimulationsTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperValidatorSimulations *SuperValidatorSimulationsRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperValidatorSimulations.Contract.SuperValidatorSimulationsTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperValidatorSimulations *SuperValidatorSimulationsCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperValidatorSimulations.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperValidatorSimulations *SuperValidatorSimulationsTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperValidatorSimulations.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperValidatorSimulations *SuperValidatorSimulationsTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperValidatorSimulations.Contract.contract.Transact(opts, method, params...)
}

// RetrieveSignatureData is a free data retrieval call binding the contract method 0x0f65bac5.
//
// Solidity: function retrieveSignatureData(address account) view returns(bytes)
func (_SuperValidatorSimulations *SuperValidatorSimulationsCaller) RetrieveSignatureData(opts *bind.CallOpts, account common.Address) ([]byte, error) {
	var out []interface{}
	err := _SuperValidatorSimulations.contract.Call(opts, &out, "retrieveSignatureData", account)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// RetrieveSignatureData is a free data retrieval call binding the contract method 0x0f65bac5.
//
// Solidity: function retrieveSignatureData(address account) view returns(bytes)
func (_SuperValidatorSimulations *SuperValidatorSimulationsSession) RetrieveSignatureData(account common.Address) ([]byte, error) {
	return _SuperValidatorSimulations.Contract.RetrieveSignatureData(&_SuperValidatorSimulations.CallOpts, account)
}

// RetrieveSignatureData is a free data retrieval call binding the contract method 0x0f65bac5.
//
// Solidity: function retrieveSignatureData(address account) view returns(bytes)
func (_SuperValidatorSimulations *SuperValidatorSimulationsCallerSession) RetrieveSignatureData(account common.Address) ([]byte, error) {
	return _SuperValidatorSimulations.Contract.RetrieveSignatureData(&_SuperValidatorSimulations.CallOpts, account)
}

// StoreSignatureData is a paid mutator transaction binding the contract method 0x5fa0bd2a.
//
// Solidity: function storeSignatureData(bytes signature, address account) returns()
func (_SuperValidatorSimulations *SuperValidatorSimulationsTransactor) StoreSignatureData(opts *bind.TransactOpts, signature []byte, account common.Address) (*types.Transaction, error) {
	return _SuperValidatorSimulations.contract.Transact(opts, "storeSignatureData", signature, account)
}

// StoreSignatureData is a paid mutator transaction binding the contract method 0x5fa0bd2a.
//
// Solidity: function storeSignatureData(bytes signature, address account) returns()
func (_SuperValidatorSimulations *SuperValidatorSimulationsSession) StoreSignatureData(signature []byte, account common.Address) (*types.Transaction, error) {
	return _SuperValidatorSimulations.Contract.StoreSignatureData(&_SuperValidatorSimulations.TransactOpts, signature, account)
}

// StoreSignatureData is a paid mutator transaction binding the contract method 0x5fa0bd2a.
//
// Solidity: function storeSignatureData(bytes signature, address account) returns()
func (_SuperValidatorSimulations *SuperValidatorSimulationsTransactorSession) StoreSignatureData(signature []byte, account common.Address) (*types.Transaction, error) {
	return _SuperValidatorSimulations.Contract.StoreSignatureData(&_SuperValidatorSimulations.TransactOpts, signature, account)
}
