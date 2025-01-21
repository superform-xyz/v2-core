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

// AcrossSendFundsAndExecuteOnDstHookMetaData contains all meta data concerning the AcrossSendFundsAndExecuteOnDstHook contract.
var AcrossSendFundsAndExecuteOnDstHookMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"registry_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"author_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"spokePoolV3_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"author\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"build\",\"inputs\":[{\"name\":\"prevHook\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"executions\",\"type\":\"tuple[]\",\"internalType\":\"structExecution[]\",\"components\":[{\"name\":\"target\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"callData\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"hookType\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"enumISuperHook.HookType\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"outAmount\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"postExecute\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"preExecute\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"spokePoolV3\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"superRegistry\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperRegistry\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AMOUNT_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_AUTHORIZED\",\"inputs\":[]}]",
}

// AcrossSendFundsAndExecuteOnDstHookABI is the input ABI used to generate the binding from.
// Deprecated: Use AcrossSendFundsAndExecuteOnDstHookMetaData.ABI instead.
var AcrossSendFundsAndExecuteOnDstHookABI = AcrossSendFundsAndExecuteOnDstHookMetaData.ABI

// AcrossSendFundsAndExecuteOnDstHook is an auto generated Go binding around an Ethereum contract.
type AcrossSendFundsAndExecuteOnDstHook struct {
	AcrossSendFundsAndExecuteOnDstHookCaller     // Read-only binding to the contract
	AcrossSendFundsAndExecuteOnDstHookTransactor // Write-only binding to the contract
	AcrossSendFundsAndExecuteOnDstHookFilterer   // Log filterer for contract events
}

// AcrossSendFundsAndExecuteOnDstHookCaller is an auto generated read-only Go binding around an Ethereum contract.
type AcrossSendFundsAndExecuteOnDstHookCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AcrossSendFundsAndExecuteOnDstHookTransactor is an auto generated write-only Go binding around an Ethereum contract.
type AcrossSendFundsAndExecuteOnDstHookTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AcrossSendFundsAndExecuteOnDstHookFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type AcrossSendFundsAndExecuteOnDstHookFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AcrossSendFundsAndExecuteOnDstHookSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type AcrossSendFundsAndExecuteOnDstHookSession struct {
	Contract     *AcrossSendFundsAndExecuteOnDstHook // Generic contract binding to set the session for
	CallOpts     bind.CallOpts                       // Call options to use throughout this session
	TransactOpts bind.TransactOpts                   // Transaction auth options to use throughout this session
}

// AcrossSendFundsAndExecuteOnDstHookCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type AcrossSendFundsAndExecuteOnDstHookCallerSession struct {
	Contract *AcrossSendFundsAndExecuteOnDstHookCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                             // Call options to use throughout this session
}

// AcrossSendFundsAndExecuteOnDstHookTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type AcrossSendFundsAndExecuteOnDstHookTransactorSession struct {
	Contract     *AcrossSendFundsAndExecuteOnDstHookTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                             // Transaction auth options to use throughout this session
}

// AcrossSendFundsAndExecuteOnDstHookRaw is an auto generated low-level Go binding around an Ethereum contract.
type AcrossSendFundsAndExecuteOnDstHookRaw struct {
	Contract *AcrossSendFundsAndExecuteOnDstHook // Generic contract binding to access the raw methods on
}

// AcrossSendFundsAndExecuteOnDstHookCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type AcrossSendFundsAndExecuteOnDstHookCallerRaw struct {
	Contract *AcrossSendFundsAndExecuteOnDstHookCaller // Generic read-only contract binding to access the raw methods on
}

// AcrossSendFundsAndExecuteOnDstHookTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type AcrossSendFundsAndExecuteOnDstHookTransactorRaw struct {
	Contract *AcrossSendFundsAndExecuteOnDstHookTransactor // Generic write-only contract binding to access the raw methods on
}

// NewAcrossSendFundsAndExecuteOnDstHook creates a new instance of AcrossSendFundsAndExecuteOnDstHook, bound to a specific deployed contract.
func NewAcrossSendFundsAndExecuteOnDstHook(address common.Address, backend bind.ContractBackend) (*AcrossSendFundsAndExecuteOnDstHook, error) {
	contract, err := bindAcrossSendFundsAndExecuteOnDstHook(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &AcrossSendFundsAndExecuteOnDstHook{AcrossSendFundsAndExecuteOnDstHookCaller: AcrossSendFundsAndExecuteOnDstHookCaller{contract: contract}, AcrossSendFundsAndExecuteOnDstHookTransactor: AcrossSendFundsAndExecuteOnDstHookTransactor{contract: contract}, AcrossSendFundsAndExecuteOnDstHookFilterer: AcrossSendFundsAndExecuteOnDstHookFilterer{contract: contract}}, nil
}

// NewAcrossSendFundsAndExecuteOnDstHookCaller creates a new read-only instance of AcrossSendFundsAndExecuteOnDstHook, bound to a specific deployed contract.
func NewAcrossSendFundsAndExecuteOnDstHookCaller(address common.Address, caller bind.ContractCaller) (*AcrossSendFundsAndExecuteOnDstHookCaller, error) {
	contract, err := bindAcrossSendFundsAndExecuteOnDstHook(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &AcrossSendFundsAndExecuteOnDstHookCaller{contract: contract}, nil
}

// NewAcrossSendFundsAndExecuteOnDstHookTransactor creates a new write-only instance of AcrossSendFundsAndExecuteOnDstHook, bound to a specific deployed contract.
func NewAcrossSendFundsAndExecuteOnDstHookTransactor(address common.Address, transactor bind.ContractTransactor) (*AcrossSendFundsAndExecuteOnDstHookTransactor, error) {
	contract, err := bindAcrossSendFundsAndExecuteOnDstHook(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &AcrossSendFundsAndExecuteOnDstHookTransactor{contract: contract}, nil
}

// NewAcrossSendFundsAndExecuteOnDstHookFilterer creates a new log filterer instance of AcrossSendFundsAndExecuteOnDstHook, bound to a specific deployed contract.
func NewAcrossSendFundsAndExecuteOnDstHookFilterer(address common.Address, filterer bind.ContractFilterer) (*AcrossSendFundsAndExecuteOnDstHookFilterer, error) {
	contract, err := bindAcrossSendFundsAndExecuteOnDstHook(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &AcrossSendFundsAndExecuteOnDstHookFilterer{contract: contract}, nil
}

// bindAcrossSendFundsAndExecuteOnDstHook binds a generic wrapper to an already deployed contract.
func bindAcrossSendFundsAndExecuteOnDstHook(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := AcrossSendFundsAndExecuteOnDstHookMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.AcrossSendFundsAndExecuteOnDstHookCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.AcrossSendFundsAndExecuteOnDstHookTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.AcrossSendFundsAndExecuteOnDstHookTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.contract.Transact(opts, method, params...)
}

// Author is a free data retrieval call binding the contract method 0xa6c3e6b9.
//
// Solidity: function author() view returns(address)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCaller) Author(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossSendFundsAndExecuteOnDstHook.contract.Call(opts, &out, "author")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Author is a free data retrieval call binding the contract method 0xa6c3e6b9.
//
// Solidity: function author() view returns(address)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookSession) Author() (common.Address, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.Author(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts)
}

// Author is a free data retrieval call binding the contract method 0xa6c3e6b9.
//
// Solidity: function author() view returns(address)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCallerSession) Author() (common.Address, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.Author(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts)
}

// Build is a free data retrieval call binding the contract method 0x7531626b.
//
// Solidity: function build(address prevHook, bytes data) view returns((address,uint256,bytes)[] executions)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCaller) Build(opts *bind.CallOpts, prevHook common.Address, data []byte) ([]Execution, error) {
	var out []interface{}
	err := _AcrossSendFundsAndExecuteOnDstHook.contract.Call(opts, &out, "build", prevHook, data)

	if err != nil {
		return *new([]Execution), err
	}

	out0 := *abi.ConvertType(out[0], new([]Execution)).(*[]Execution)

	return out0, err

}

// Build is a free data retrieval call binding the contract method 0x7531626b.
//
// Solidity: function build(address prevHook, bytes data) view returns((address,uint256,bytes)[] executions)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookSession) Build(prevHook common.Address, data []byte) ([]Execution, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.Build(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts, prevHook, data)
}

// Build is a free data retrieval call binding the contract method 0x7531626b.
//
// Solidity: function build(address prevHook, bytes data) view returns((address,uint256,bytes)[] executions)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCallerSession) Build(prevHook common.Address, data []byte) ([]Execution, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.Build(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts, prevHook, data)
}

// HookType is a free data retrieval call binding the contract method 0xe445e7dd.
//
// Solidity: function hookType() view returns(uint8)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCaller) HookType(opts *bind.CallOpts) (uint8, error) {
	var out []interface{}
	err := _AcrossSendFundsAndExecuteOnDstHook.contract.Call(opts, &out, "hookType")

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// HookType is a free data retrieval call binding the contract method 0xe445e7dd.
//
// Solidity: function hookType() view returns(uint8)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookSession) HookType() (uint8, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.HookType(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts)
}

// HookType is a free data retrieval call binding the contract method 0xe445e7dd.
//
// Solidity: function hookType() view returns(uint8)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCallerSession) HookType() (uint8, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.HookType(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts)
}

// OutAmount is a free data retrieval call binding the contract method 0xe0b95720.
//
// Solidity: function outAmount() view returns(uint256)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCaller) OutAmount(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossSendFundsAndExecuteOnDstHook.contract.Call(opts, &out, "outAmount")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// OutAmount is a free data retrieval call binding the contract method 0xe0b95720.
//
// Solidity: function outAmount() view returns(uint256)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookSession) OutAmount() (*big.Int, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.OutAmount(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts)
}

// OutAmount is a free data retrieval call binding the contract method 0xe0b95720.
//
// Solidity: function outAmount() view returns(uint256)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCallerSession) OutAmount() (*big.Int, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.OutAmount(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts)
}

// PostExecute is a free data retrieval call binding the contract method 0x99e99aff.
//
// Solidity: function postExecute(address , bytes ) view returns()
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCaller) PostExecute(opts *bind.CallOpts, arg0 common.Address, arg1 []byte) error {
	var out []interface{}
	err := _AcrossSendFundsAndExecuteOnDstHook.contract.Call(opts, &out, "postExecute", arg0, arg1)

	if err != nil {
		return err
	}

	return err

}

// PostExecute is a free data retrieval call binding the contract method 0x99e99aff.
//
// Solidity: function postExecute(address , bytes ) view returns()
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookSession) PostExecute(arg0 common.Address, arg1 []byte) error {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.PostExecute(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts, arg0, arg1)
}

// PostExecute is a free data retrieval call binding the contract method 0x99e99aff.
//
// Solidity: function postExecute(address , bytes ) view returns()
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCallerSession) PostExecute(arg0 common.Address, arg1 []byte) error {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.PostExecute(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts, arg0, arg1)
}

// PreExecute is a free data retrieval call binding the contract method 0x7251d7b3.
//
// Solidity: function preExecute(address , bytes ) view returns()
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCaller) PreExecute(opts *bind.CallOpts, arg0 common.Address, arg1 []byte) error {
	var out []interface{}
	err := _AcrossSendFundsAndExecuteOnDstHook.contract.Call(opts, &out, "preExecute", arg0, arg1)

	if err != nil {
		return err
	}

	return err

}

// PreExecute is a free data retrieval call binding the contract method 0x7251d7b3.
//
// Solidity: function preExecute(address , bytes ) view returns()
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookSession) PreExecute(arg0 common.Address, arg1 []byte) error {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.PreExecute(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts, arg0, arg1)
}

// PreExecute is a free data retrieval call binding the contract method 0x7251d7b3.
//
// Solidity: function preExecute(address , bytes ) view returns()
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCallerSession) PreExecute(arg0 common.Address, arg1 []byte) error {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.PreExecute(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts, arg0, arg1)
}

// SpokePoolV3 is a free data retrieval call binding the contract method 0x3c02c770.
//
// Solidity: function spokePoolV3() view returns(address)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCaller) SpokePoolV3(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossSendFundsAndExecuteOnDstHook.contract.Call(opts, &out, "spokePoolV3")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SpokePoolV3 is a free data retrieval call binding the contract method 0x3c02c770.
//
// Solidity: function spokePoolV3() view returns(address)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookSession) SpokePoolV3() (common.Address, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.SpokePoolV3(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts)
}

// SpokePoolV3 is a free data retrieval call binding the contract method 0x3c02c770.
//
// Solidity: function spokePoolV3() view returns(address)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCallerSession) SpokePoolV3() (common.Address, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.SpokePoolV3(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts)
}

// SuperRegistry is a free data retrieval call binding the contract method 0x24c73dda.
//
// Solidity: function superRegistry() view returns(address)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCaller) SuperRegistry(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossSendFundsAndExecuteOnDstHook.contract.Call(opts, &out, "superRegistry")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SuperRegistry is a free data retrieval call binding the contract method 0x24c73dda.
//
// Solidity: function superRegistry() view returns(address)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookSession) SuperRegistry() (common.Address, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.SuperRegistry(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts)
}

// SuperRegistry is a free data retrieval call binding the contract method 0x24c73dda.
//
// Solidity: function superRegistry() view returns(address)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCallerSession) SuperRegistry() (common.Address, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.SuperRegistry(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts)
}
