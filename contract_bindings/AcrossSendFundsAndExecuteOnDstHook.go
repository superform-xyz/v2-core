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
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"registry_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"spokePoolV3_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"asset\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"build\",\"inputs\":[{\"name\":\"prevHook\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"executions\",\"type\":\"tuple[]\",\"internalType\":\"structExecution[]\",\"components\":[{\"name\":\"target\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"callData\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"decodeUsePrevHookAmount\",\"inputs\":[{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getExecutionCaller\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"hookType\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"enumISuperHook.HookType\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"lastExecutionCaller\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"lockForSP\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"outAmount\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"postExecute\",\"inputs\":[{\"name\":\"prevHook\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"preExecute\",\"inputs\":[{\"name\":\"prevHook\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"spToken\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"spokePoolV3\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"superRegistry\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperRegistry\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"usedShares\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AMOUNT_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"DATA_LENGTH_INSUFFICIENT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_AUTHORIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]}]",
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

// Asset is a free data retrieval call binding the contract method 0x38d52e0f.
//
// Solidity: function asset() view returns(address)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCaller) Asset(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossSendFundsAndExecuteOnDstHook.contract.Call(opts, &out, "asset")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Asset is a free data retrieval call binding the contract method 0x38d52e0f.
//
// Solidity: function asset() view returns(address)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookSession) Asset() (common.Address, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.Asset(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts)
}

// Asset is a free data retrieval call binding the contract method 0x38d52e0f.
//
// Solidity: function asset() view returns(address)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCallerSession) Asset() (common.Address, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.Asset(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts)
}

// Build is a free data retrieval call binding the contract method 0x3b5896bc.
//
// Solidity: function build(address prevHook, address account, bytes data) view returns((address,uint256,bytes)[] executions)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCaller) Build(opts *bind.CallOpts, prevHook common.Address, account common.Address, data []byte) ([]Execution, error) {
	var out []interface{}
	err := _AcrossSendFundsAndExecuteOnDstHook.contract.Call(opts, &out, "build", prevHook, account, data)

	if err != nil {
		return *new([]Execution), err
	}

	out0 := *abi.ConvertType(out[0], new([]Execution)).(*[]Execution)

	return out0, err

}

// Build is a free data retrieval call binding the contract method 0x3b5896bc.
//
// Solidity: function build(address prevHook, address account, bytes data) view returns((address,uint256,bytes)[] executions)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookSession) Build(prevHook common.Address, account common.Address, data []byte) ([]Execution, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.Build(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts, prevHook, account, data)
}

// Build is a free data retrieval call binding the contract method 0x3b5896bc.
//
// Solidity: function build(address prevHook, address account, bytes data) view returns((address,uint256,bytes)[] executions)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCallerSession) Build(prevHook common.Address, account common.Address, data []byte) ([]Execution, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.Build(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts, prevHook, account, data)
}

// DecodeUsePrevHookAmount is a free data retrieval call binding the contract method 0xe7745517.
//
// Solidity: function decodeUsePrevHookAmount(bytes data) pure returns(bool)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCaller) DecodeUsePrevHookAmount(opts *bind.CallOpts, data []byte) (bool, error) {
	var out []interface{}
	err := _AcrossSendFundsAndExecuteOnDstHook.contract.Call(opts, &out, "decodeUsePrevHookAmount", data)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// DecodeUsePrevHookAmount is a free data retrieval call binding the contract method 0xe7745517.
//
// Solidity: function decodeUsePrevHookAmount(bytes data) pure returns(bool)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookSession) DecodeUsePrevHookAmount(data []byte) (bool, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.DecodeUsePrevHookAmount(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts, data)
}

// DecodeUsePrevHookAmount is a free data retrieval call binding the contract method 0xe7745517.
//
// Solidity: function decodeUsePrevHookAmount(bytes data) pure returns(bool)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCallerSession) DecodeUsePrevHookAmount(data []byte) (bool, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.DecodeUsePrevHookAmount(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts, data)
}

// GetExecutionCaller is a free data retrieval call binding the contract method 0x6aa04ec5.
//
// Solidity: function getExecutionCaller() view returns(address)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCaller) GetExecutionCaller(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossSendFundsAndExecuteOnDstHook.contract.Call(opts, &out, "getExecutionCaller")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetExecutionCaller is a free data retrieval call binding the contract method 0x6aa04ec5.
//
// Solidity: function getExecutionCaller() view returns(address)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookSession) GetExecutionCaller() (common.Address, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.GetExecutionCaller(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts)
}

// GetExecutionCaller is a free data retrieval call binding the contract method 0x6aa04ec5.
//
// Solidity: function getExecutionCaller() view returns(address)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCallerSession) GetExecutionCaller() (common.Address, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.GetExecutionCaller(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts)
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

// LastExecutionCaller is a free data retrieval call binding the contract method 0x82c3c729.
//
// Solidity: function lastExecutionCaller() view returns(address)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCaller) LastExecutionCaller(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossSendFundsAndExecuteOnDstHook.contract.Call(opts, &out, "lastExecutionCaller")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// LastExecutionCaller is a free data retrieval call binding the contract method 0x82c3c729.
//
// Solidity: function lastExecutionCaller() view returns(address)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookSession) LastExecutionCaller() (common.Address, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.LastExecutionCaller(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts)
}

// LastExecutionCaller is a free data retrieval call binding the contract method 0x82c3c729.
//
// Solidity: function lastExecutionCaller() view returns(address)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCallerSession) LastExecutionCaller() (common.Address, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.LastExecutionCaller(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts)
}

// LockForSP is a free data retrieval call binding the contract method 0x514ea109.
//
// Solidity: function lockForSP() view returns(bool)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCaller) LockForSP(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _AcrossSendFundsAndExecuteOnDstHook.contract.Call(opts, &out, "lockForSP")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// LockForSP is a free data retrieval call binding the contract method 0x514ea109.
//
// Solidity: function lockForSP() view returns(bool)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookSession) LockForSP() (bool, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.LockForSP(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts)
}

// LockForSP is a free data retrieval call binding the contract method 0x514ea109.
//
// Solidity: function lockForSP() view returns(bool)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCallerSession) LockForSP() (bool, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.LockForSP(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts)
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

// SpToken is a free data retrieval call binding the contract method 0x8e148776.
//
// Solidity: function spToken() view returns(address)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCaller) SpToken(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossSendFundsAndExecuteOnDstHook.contract.Call(opts, &out, "spToken")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SpToken is a free data retrieval call binding the contract method 0x8e148776.
//
// Solidity: function spToken() view returns(address)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookSession) SpToken() (common.Address, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.SpToken(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts)
}

// SpToken is a free data retrieval call binding the contract method 0x8e148776.
//
// Solidity: function spToken() view returns(address)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCallerSession) SpToken() (common.Address, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.SpToken(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts)
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

// UsedShares is a free data retrieval call binding the contract method 0x685a943c.
//
// Solidity: function usedShares() view returns(uint256)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCaller) UsedShares(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AcrossSendFundsAndExecuteOnDstHook.contract.Call(opts, &out, "usedShares")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// UsedShares is a free data retrieval call binding the contract method 0x685a943c.
//
// Solidity: function usedShares() view returns(uint256)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookSession) UsedShares() (*big.Int, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.UsedShares(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts)
}

// UsedShares is a free data retrieval call binding the contract method 0x685a943c.
//
// Solidity: function usedShares() view returns(uint256)
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookCallerSession) UsedShares() (*big.Int, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.UsedShares(&_AcrossSendFundsAndExecuteOnDstHook.CallOpts)
}

// PostExecute is a paid mutator transaction binding the contract method 0x05b4fe91.
//
// Solidity: function postExecute(address prevHook, address account, bytes data) returns()
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookTransactor) PostExecute(opts *bind.TransactOpts, prevHook common.Address, account common.Address, data []byte) (*types.Transaction, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.contract.Transact(opts, "postExecute", prevHook, account, data)
}

// PostExecute is a paid mutator transaction binding the contract method 0x05b4fe91.
//
// Solidity: function postExecute(address prevHook, address account, bytes data) returns()
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookSession) PostExecute(prevHook common.Address, account common.Address, data []byte) (*types.Transaction, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.PostExecute(&_AcrossSendFundsAndExecuteOnDstHook.TransactOpts, prevHook, account, data)
}

// PostExecute is a paid mutator transaction binding the contract method 0x05b4fe91.
//
// Solidity: function postExecute(address prevHook, address account, bytes data) returns()
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookTransactorSession) PostExecute(prevHook common.Address, account common.Address, data []byte) (*types.Transaction, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.PostExecute(&_AcrossSendFundsAndExecuteOnDstHook.TransactOpts, prevHook, account, data)
}

// PreExecute is a paid mutator transaction binding the contract method 0x2ae2fe3d.
//
// Solidity: function preExecute(address prevHook, address account, bytes data) returns()
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookTransactor) PreExecute(opts *bind.TransactOpts, prevHook common.Address, account common.Address, data []byte) (*types.Transaction, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.contract.Transact(opts, "preExecute", prevHook, account, data)
}

// PreExecute is a paid mutator transaction binding the contract method 0x2ae2fe3d.
//
// Solidity: function preExecute(address prevHook, address account, bytes data) returns()
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookSession) PreExecute(prevHook common.Address, account common.Address, data []byte) (*types.Transaction, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.PreExecute(&_AcrossSendFundsAndExecuteOnDstHook.TransactOpts, prevHook, account, data)
}

// PreExecute is a paid mutator transaction binding the contract method 0x2ae2fe3d.
//
// Solidity: function preExecute(address prevHook, address account, bytes data) returns()
func (_AcrossSendFundsAndExecuteOnDstHook *AcrossSendFundsAndExecuteOnDstHookTransactorSession) PreExecute(prevHook common.Address, account common.Address, data []byte) (*types.Transaction, error) {
	return _AcrossSendFundsAndExecuteOnDstHook.Contract.PreExecute(&_AcrossSendFundsAndExecuteOnDstHook.TransactOpts, prevHook, account, data)
}
