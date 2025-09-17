// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperValidatorStateOverride

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

// SuperValidatorStateOverrideMetaData contains all meta data concerning the SuperValidatorStateOverride contract.
var SuperValidatorStateOverrideMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"retrieveSignatureData\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"view\"}]",
}

// SuperValidatorStateOverrideABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperValidatorStateOverrideMetaData.ABI instead.
var SuperValidatorStateOverrideABI = SuperValidatorStateOverrideMetaData.ABI

// SuperValidatorStateOverride is an auto generated Go binding around an Ethereum contract.
type SuperValidatorStateOverride struct {
	SuperValidatorStateOverrideCaller     // Read-only binding to the contract
	SuperValidatorStateOverrideTransactor // Write-only binding to the contract
	SuperValidatorStateOverrideFilterer   // Log filterer for contract events
}

// SuperValidatorStateOverrideCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperValidatorStateOverrideCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperValidatorStateOverrideTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperValidatorStateOverrideTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperValidatorStateOverrideFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperValidatorStateOverrideFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperValidatorStateOverrideSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperValidatorStateOverrideSession struct {
	Contract     *SuperValidatorStateOverride // Generic contract binding to set the session for
	CallOpts     bind.CallOpts                // Call options to use throughout this session
	TransactOpts bind.TransactOpts            // Transaction auth options to use throughout this session
}

// SuperValidatorStateOverrideCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperValidatorStateOverrideCallerSession struct {
	Contract *SuperValidatorStateOverrideCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                      // Call options to use throughout this session
}

// SuperValidatorStateOverrideTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperValidatorStateOverrideTransactorSession struct {
	Contract     *SuperValidatorStateOverrideTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                      // Transaction auth options to use throughout this session
}

// SuperValidatorStateOverrideRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperValidatorStateOverrideRaw struct {
	Contract *SuperValidatorStateOverride // Generic contract binding to access the raw methods on
}

// SuperValidatorStateOverrideCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperValidatorStateOverrideCallerRaw struct {
	Contract *SuperValidatorStateOverrideCaller // Generic read-only contract binding to access the raw methods on
}

// SuperValidatorStateOverrideTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperValidatorStateOverrideTransactorRaw struct {
	Contract *SuperValidatorStateOverrideTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperValidatorStateOverride creates a new instance of SuperValidatorStateOverride, bound to a specific deployed contract.
func NewSuperValidatorStateOverride(address common.Address, backend bind.ContractBackend) (*SuperValidatorStateOverride, error) {
	contract, err := bindSuperValidatorStateOverride(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperValidatorStateOverride{SuperValidatorStateOverrideCaller: SuperValidatorStateOverrideCaller{contract: contract}, SuperValidatorStateOverrideTransactor: SuperValidatorStateOverrideTransactor{contract: contract}, SuperValidatorStateOverrideFilterer: SuperValidatorStateOverrideFilterer{contract: contract}}, nil
}

// NewSuperValidatorStateOverrideCaller creates a new read-only instance of SuperValidatorStateOverride, bound to a specific deployed contract.
func NewSuperValidatorStateOverrideCaller(address common.Address, caller bind.ContractCaller) (*SuperValidatorStateOverrideCaller, error) {
	contract, err := bindSuperValidatorStateOverride(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperValidatorStateOverrideCaller{contract: contract}, nil
}

// NewSuperValidatorStateOverrideTransactor creates a new write-only instance of SuperValidatorStateOverride, bound to a specific deployed contract.
func NewSuperValidatorStateOverrideTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperValidatorStateOverrideTransactor, error) {
	contract, err := bindSuperValidatorStateOverride(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperValidatorStateOverrideTransactor{contract: contract}, nil
}

// NewSuperValidatorStateOverrideFilterer creates a new log filterer instance of SuperValidatorStateOverride, bound to a specific deployed contract.
func NewSuperValidatorStateOverrideFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperValidatorStateOverrideFilterer, error) {
	contract, err := bindSuperValidatorStateOverride(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperValidatorStateOverrideFilterer{contract: contract}, nil
}

// bindSuperValidatorStateOverride binds a generic wrapper to an already deployed contract.
func bindSuperValidatorStateOverride(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperValidatorStateOverrideMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperValidatorStateOverride *SuperValidatorStateOverrideRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperValidatorStateOverride.Contract.SuperValidatorStateOverrideCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperValidatorStateOverride *SuperValidatorStateOverrideRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperValidatorStateOverride.Contract.SuperValidatorStateOverrideTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperValidatorStateOverride *SuperValidatorStateOverrideRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperValidatorStateOverride.Contract.SuperValidatorStateOverrideTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperValidatorStateOverride *SuperValidatorStateOverrideCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperValidatorStateOverride.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperValidatorStateOverride *SuperValidatorStateOverrideTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperValidatorStateOverride.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperValidatorStateOverride *SuperValidatorStateOverrideTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperValidatorStateOverride.Contract.contract.Transact(opts, method, params...)
}

// RetrieveSignatureData is a free data retrieval call binding the contract method 0x0f65bac5.
//
// Solidity: function retrieveSignatureData(address account) view returns(bytes)
func (_SuperValidatorStateOverride *SuperValidatorStateOverrideCaller) RetrieveSignatureData(opts *bind.CallOpts, account common.Address) ([]byte, error) {
	var out []interface{}
	err := _SuperValidatorStateOverride.contract.Call(opts, &out, "retrieveSignatureData", account)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// RetrieveSignatureData is a free data retrieval call binding the contract method 0x0f65bac5.
//
// Solidity: function retrieveSignatureData(address account) view returns(bytes)
func (_SuperValidatorStateOverride *SuperValidatorStateOverrideSession) RetrieveSignatureData(account common.Address) ([]byte, error) {
	return _SuperValidatorStateOverride.Contract.RetrieveSignatureData(&_SuperValidatorStateOverride.CallOpts, account)
}

// RetrieveSignatureData is a free data retrieval call binding the contract method 0x0f65bac5.
//
// Solidity: function retrieveSignatureData(address account) view returns(bytes)
func (_SuperValidatorStateOverride *SuperValidatorStateOverrideCallerSession) RetrieveSignatureData(account common.Address) ([]byte, error) {
	return _SuperValidatorStateOverride.Contract.RetrieveSignatureData(&_SuperValidatorStateOverride.CallOpts, account)
}
