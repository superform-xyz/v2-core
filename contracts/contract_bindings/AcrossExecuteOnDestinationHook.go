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

// Execution is an auto generated low-level Go binding around an user-defined struct.
type Execution struct {
	Target   common.Address
	Value    *big.Int
	CallData []byte
}

// AcrossExecuteOnDestinationHookMetaData contains all meta data concerning the AcrossExecuteOnDestinationHook contract.
var AcrossExecuteOnDestinationHookMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"registry_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"author_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"spokePoolV3_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"author\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"build\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"executions\",\"type\":\"tuple[]\",\"internalType\":\"structExecution[]\",\"components\":[{\"name\":\"target\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"callData\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"hookType\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"enumISuperHook.HookType\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"outAmount\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"postExecute\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"preExecute\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"spokePoolV3\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"superRegistry\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperRegistry\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AMOUNT_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_AUTHORIZED\",\"inputs\":[]}]",
}

// AcrossExecuteOnDestinationHookABI is the input ABI used to generate the binding from.
// Deprecated: Use AcrossExecuteOnDestinationHookMetaData.ABI instead.
var AcrossExecuteOnDestinationHookABI = AcrossExecuteOnDestinationHookMetaData.ABI

// AcrossExecuteOnDestinationHook is an auto generated Go binding around an Ethereum contract.
type AcrossExecuteOnDestinationHook struct {
	AcrossExecuteOnDestinationHookCaller     // Read-only binding to the contract
	AcrossExecuteOnDestinationHookTransactor // Write-only binding to the contract
	AcrossExecuteOnDestinationHookFilterer   // Log filterer for contract events
}

// AcrossExecuteOnDestinationHookCaller is an auto generated read-only Go binding around an Ethereum contract.
type AcrossExecuteOnDestinationHookCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AcrossExecuteOnDestinationHookTransactor is an auto generated write-only Go binding around an Ethereum contract.
type AcrossExecuteOnDestinationHookTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AcrossExecuteOnDestinationHookFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type AcrossExecuteOnDestinationHookFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AcrossExecuteOnDestinationHookSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type AcrossExecuteOnDestinationHookSession struct {
	Contract     *AcrossExecuteOnDestinationHook // Generic contract binding to set the session for
	CallOpts     bind.CallOpts                   // Call options to use throughout this session
	TransactOpts bind.TransactOpts               // Transaction auth options to use throughout this session
}

// AcrossExecuteOnDestinationHookCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type AcrossExecuteOnDestinationHookCallerSession struct {
	Contract *AcrossExecuteOnDestinationHookCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                         // Call options to use throughout this session
}

// AcrossExecuteOnDestinationHookTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type AcrossExecuteOnDestinationHookTransactorSession struct {
	Contract     *AcrossExecuteOnDestinationHookTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                         // Transaction auth options to use throughout this session
}

// AcrossExecuteOnDestinationHookRaw is an auto generated low-level Go binding around an Ethereum contract.
type AcrossExecuteOnDestinationHookRaw struct {
	Contract *AcrossExecuteOnDestinationHook // Generic contract binding to access the raw methods on
}

// AcrossExecuteOnDestinationHookCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type AcrossExecuteOnDestinationHookCallerRaw struct {
	Contract *AcrossExecuteOnDestinationHookCaller // Generic read-only contract binding to access the raw methods on
}

// AcrossExecuteOnDestinationHookTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type AcrossExecuteOnDestinationHookTransactorRaw struct {
	Contract *AcrossExecuteOnDestinationHookTransactor // Generic write-only contract binding to access the raw methods on
}

// NewAcrossExecuteOnDestinationHook creates a new instance of AcrossExecuteOnDestinationHook, bound to a specific deployed contract.
func NewAcrossExecuteOnDestinationHook(address common.Address, backend bind.ContractBackend) (*AcrossExecuteOnDestinationHook, error) {
	contract, err := bindAcrossExecuteOnDestinationHook(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &AcrossExecuteOnDestinationHook{AcrossExecuteOnDestinationHookCaller: AcrossExecuteOnDestinationHookCaller{contract: contract}, AcrossExecuteOnDestinationHookTransactor: AcrossExecuteOnDestinationHookTransactor{contract: contract}, AcrossExecuteOnDestinationHookFilterer: AcrossExecuteOnDestinationHookFilterer{contract: contract}}, nil
}

// NewAcrossExecuteOnDestinationHookCaller creates a new read-only instance of AcrossExecuteOnDestinationHook, bound to a specific deployed contract.
func NewAcrossExecuteOnDestinationHookCaller(address common.Address, caller bind.ContractCaller) (*AcrossExecuteOnDestinationHookCaller, error) {
	contract, err := bindAcrossExecuteOnDestinationHook(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &AcrossExecuteOnDestinationHookCaller{contract: contract}, nil
}

// NewAcrossExecuteOnDestinationHookTransactor creates a new write-only instance of AcrossExecuteOnDestinationHook, bound to a specific deployed contract.
func NewAcrossExecuteOnDestinationHookTransactor(address common.Address, transactor bind.ContractTransactor) (*AcrossExecuteOnDestinationHookTransactor, error) {
	contract, err := bindAcrossExecuteOnDestinationHook(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &AcrossExecuteOnDestinationHookTransactor{contract: contract}, nil
}

// NewAcrossExecuteOnDestinationHookFilterer creates a new log filterer instance of AcrossExecuteOnDestinationHook, bound to a specific deployed contract.
func NewAcrossExecuteOnDestinationHookFilterer(address common.Address, filterer bind.ContractFilterer) (*AcrossExecuteOnDestinationHookFilterer, error) {
	contract, err := bindAcrossExecuteOnDestinationHook(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &AcrossExecuteOnDestinationHookFilterer{contract: contract}, nil
}

// bindAcrossExecuteOnDestinationHook binds a generic wrapper to an already deployed contract.
func bindAcrossExecuteOnDestinationHook(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := AcrossExecuteOnDestinationHookMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _AcrossExecuteOnDestinationHook.Contract.AcrossExecuteOnDestinationHookCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossExecuteOnDestinationHook.Contract.AcrossExecuteOnDestinationHookTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _AcrossExecuteOnDestinationHook.Contract.AcrossExecuteOnDestinationHookTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _AcrossExecuteOnDestinationHook.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossExecuteOnDestinationHook.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _AcrossExecuteOnDestinationHook.Contract.contract.Transact(opts, method, params...)
}

// Author is a free data retrieval call binding the contract method 0xa6c3e6b9.
//
// Solidity: function author() view returns(address)
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookCaller) Author(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossExecuteOnDestinationHook.contract.Call(opts, &out, "author")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Author is a free data retrieval call binding the contract method 0xa6c3e6b9.
//
// Solidity: function author() view returns(address)
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookSession) Author() (common.Address, error) {
	return _AcrossExecuteOnDestinationHook.Contract.Author(&_AcrossExecuteOnDestinationHook.CallOpts)
}

// Author is a free data retrieval call binding the contract method 0xa6c3e6b9.
//
// Solidity: function author() view returns(address)
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookCallerSession) Author() (common.Address, error) {
	return _AcrossExecuteOnDestinationHook.Contract.Author(&_AcrossExecuteOnDestinationHook.CallOpts)
}

// Build is a free data retrieval call binding the contract method 0x7531626b.
//
// Solidity: function build(address , bytes data) view returns((address,uint256,bytes)[] executions)
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookCaller) Build(opts *bind.CallOpts, arg0 common.Address, data []byte) ([]Execution, error) {
	var out []interface{}
	err := _AcrossExecuteOnDestinationHook.contract.Call(opts, &out, "build", arg0, data)

	if err != nil {
		return *new([]Execution), err
	}

	out0 := *abi.ConvertType(out[0], new([]Execution)).(*[]Execution)

	return out0, err

}

// Build is a free data retrieval call binding the contract method 0x7531626b.
//
// Solidity: function build(address , bytes data) view returns((address,uint256,bytes)[] executions)
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookSession) Build(arg0 common.Address, data []byte) ([]Execution, error) {
	return _AcrossExecuteOnDestinationHook.Contract.Build(&_AcrossExecuteOnDestinationHook.CallOpts, arg0, data)
}

// Build is a free data retrieval call binding the contract method 0x7531626b.
//
// Solidity: function build(address , bytes data) view returns((address,uint256,bytes)[] executions)
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookCallerSession) Build(arg0 common.Address, data []byte) ([]Execution, error) {
	return _AcrossExecuteOnDestinationHook.Contract.Build(&_AcrossExecuteOnDestinationHook.CallOpts, arg0, data)
}

// HookType is a free data retrieval call binding the contract method 0xe445e7dd.
//
// Solidity: function hookType() view returns(uint8)
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookCaller) HookType(opts *bind.CallOpts) (uint8, error) {
	var out []interface{}
	err := _AcrossExecuteOnDestinationHook.contract.Call(opts, &out, "hookType")

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// HookType is a free data retrieval call binding the contract method 0xe445e7dd.
//
// Solidity: function hookType() view returns(uint8)
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookSession) HookType() (uint8, error) {
	return _AcrossExecuteOnDestinationHook.Contract.HookType(&_AcrossExecuteOnDestinationHook.CallOpts)
}

// HookType is a free data retrieval call binding the contract method 0xe445e7dd.
//
// Solidity: function hookType() view returns(uint8)
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookCallerSession) HookType() (uint8, error) {
	return _AcrossExecuteOnDestinationHook.Contract.HookType(&_AcrossExecuteOnDestinationHook.CallOpts)
}

// OutAmount is a free data retrieval call binding the contract method 0xe0b95720.
//
// Solidity: function outAmount() view returns(uint256)
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookCaller) OutAmount(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossExecuteOnDestinationHook.contract.Call(opts, &out, "outAmount")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// OutAmount is a free data retrieval call binding the contract method 0xe0b95720.
//
// Solidity: function outAmount() view returns(uint256)
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookSession) OutAmount() (*big.Int, error) {
	return _AcrossExecuteOnDestinationHook.Contract.OutAmount(&_AcrossExecuteOnDestinationHook.CallOpts)
}

// OutAmount is a free data retrieval call binding the contract method 0xe0b95720.
//
// Solidity: function outAmount() view returns(uint256)
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookCallerSession) OutAmount() (*big.Int, error) {
	return _AcrossExecuteOnDestinationHook.Contract.OutAmount(&_AcrossExecuteOnDestinationHook.CallOpts)
}

// PostExecute is a free data retrieval call binding the contract method 0x99e99aff.
//
// Solidity: function postExecute(address , bytes ) view returns()
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookCaller) PostExecute(opts *bind.CallOpts, arg0 common.Address, arg1 []byte) error {
	var out []interface{}
	err := _AcrossExecuteOnDestinationHook.contract.Call(opts, &out, "postExecute", arg0, arg1)

	if err != nil {
		return err
	}

	return err

}

// PostExecute is a free data retrieval call binding the contract method 0x99e99aff.
//
// Solidity: function postExecute(address , bytes ) view returns()
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookSession) PostExecute(arg0 common.Address, arg1 []byte) error {
	return _AcrossExecuteOnDestinationHook.Contract.PostExecute(&_AcrossExecuteOnDestinationHook.CallOpts, arg0, arg1)
}

// PostExecute is a free data retrieval call binding the contract method 0x99e99aff.
//
// Solidity: function postExecute(address , bytes ) view returns()
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookCallerSession) PostExecute(arg0 common.Address, arg1 []byte) error {
	return _AcrossExecuteOnDestinationHook.Contract.PostExecute(&_AcrossExecuteOnDestinationHook.CallOpts, arg0, arg1)
}

// PreExecute is a free data retrieval call binding the contract method 0x7251d7b3.
//
// Solidity: function preExecute(address , bytes ) view returns()
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookCaller) PreExecute(opts *bind.CallOpts, arg0 common.Address, arg1 []byte) error {
	var out []interface{}
	err := _AcrossExecuteOnDestinationHook.contract.Call(opts, &out, "preExecute", arg0, arg1)

	if err != nil {
		return err
	}

	return err

}

// PreExecute is a free data retrieval call binding the contract method 0x7251d7b3.
//
// Solidity: function preExecute(address , bytes ) view returns()
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookSession) PreExecute(arg0 common.Address, arg1 []byte) error {
	return _AcrossExecuteOnDestinationHook.Contract.PreExecute(&_AcrossExecuteOnDestinationHook.CallOpts, arg0, arg1)
}

// PreExecute is a free data retrieval call binding the contract method 0x7251d7b3.
//
// Solidity: function preExecute(address , bytes ) view returns()
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookCallerSession) PreExecute(arg0 common.Address, arg1 []byte) error {
	return _AcrossExecuteOnDestinationHook.Contract.PreExecute(&_AcrossExecuteOnDestinationHook.CallOpts, arg0, arg1)
}

// SpokePoolV3 is a free data retrieval call binding the contract method 0x3c02c770.
//
// Solidity: function spokePoolV3() view returns(address)
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookCaller) SpokePoolV3(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossExecuteOnDestinationHook.contract.Call(opts, &out, "spokePoolV3")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SpokePoolV3 is a free data retrieval call binding the contract method 0x3c02c770.
//
// Solidity: function spokePoolV3() view returns(address)
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookSession) SpokePoolV3() (common.Address, error) {
	return _AcrossExecuteOnDestinationHook.Contract.SpokePoolV3(&_AcrossExecuteOnDestinationHook.CallOpts)
}

// SpokePoolV3 is a free data retrieval call binding the contract method 0x3c02c770.
//
// Solidity: function spokePoolV3() view returns(address)
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookCallerSession) SpokePoolV3() (common.Address, error) {
	return _AcrossExecuteOnDestinationHook.Contract.SpokePoolV3(&_AcrossExecuteOnDestinationHook.CallOpts)
}

// SuperRegistry is a free data retrieval call binding the contract method 0x24c73dda.
//
// Solidity: function superRegistry() view returns(address)
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookCaller) SuperRegistry(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossExecuteOnDestinationHook.contract.Call(opts, &out, "superRegistry")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SuperRegistry is a free data retrieval call binding the contract method 0x24c73dda.
//
// Solidity: function superRegistry() view returns(address)
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookSession) SuperRegistry() (common.Address, error) {
	return _AcrossExecuteOnDestinationHook.Contract.SuperRegistry(&_AcrossExecuteOnDestinationHook.CallOpts)
}

// SuperRegistry is a free data retrieval call binding the contract method 0x24c73dda.
//
// Solidity: function superRegistry() view returns(address)
func (_AcrossExecuteOnDestinationHook *AcrossExecuteOnDestinationHookCallerSession) SuperRegistry() (common.Address, error) {
	return _AcrossExecuteOnDestinationHook.Contract.SuperRegistry(&_AcrossExecuteOnDestinationHook.CallOpts)
}
