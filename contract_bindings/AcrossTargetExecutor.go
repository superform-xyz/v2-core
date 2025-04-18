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

// AcrossTargetExecutorMetaData contains all meta data concerning the AcrossTargetExecutor contract.
var AcrossTargetExecutorMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"ledgerConfiguration_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"acrossSpokePool_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"superDestinationValidator_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"nexusFactory_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"acrossSpokePool\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"execute\",\"inputs\":[{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"handleV3AcrossMessage\",\"inputs\":[{\"name\":\"tokenSent\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"message\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isInitialized\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isModuleType\",\"inputs\":[{\"name\":\"typeID\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"ledgerConfiguration\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperLedgerConfiguration\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"name\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"nexusFactory\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractINexusFactory\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"nonces\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"onInstall\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"onUninstall\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"superDestinationValidator\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"version\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"pure\"},{\"type\":\"event\",\"name\":\"AcrossFundsReceivedAndExecuted\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AcrossFundsReceivedButExecutionFailed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AcrossFundsReceivedButNotEnoughBalance\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AcrossTargetExecutorExecuted\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AcrossTargetExecutorFailed\",\"inputs\":[{\"name\":\"reason\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AcrossTargetExecutorFailedLowLevel\",\"inputs\":[{\"name\":\"lowLevelData\",\"type\":\"bytes\",\"indexed\":false,\"internalType\":\"bytes\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AcrossTargetExecutorReceivedButNoHooks\",\"inputs\":[],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AcrossTargetExecutorReceivedButNotEnoughBalance\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperPositionLocked\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"spToken\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCOUNT_NOT_CREATED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_ACCOUNT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ALREADY_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FEE_NOT_TRANSFERRED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_BALANCE_FOR_FEE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_ACCOUNT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_FEE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_SENDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_SIGNATURE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MANAGER_NOT_SET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ModuleAlreadyInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"NOT_AUTHORIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_HOOKS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"ReentrancyGuardReentrantCall\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SafeERC20FailedOperation\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}]}]",
}

// AcrossTargetExecutorABI is the input ABI used to generate the binding from.
// Deprecated: Use AcrossTargetExecutorMetaData.ABI instead.
var AcrossTargetExecutorABI = AcrossTargetExecutorMetaData.ABI

// AcrossTargetExecutor is an auto generated Go binding around an Ethereum contract.
type AcrossTargetExecutor struct {
	AcrossTargetExecutorCaller     // Read-only binding to the contract
	AcrossTargetExecutorTransactor // Write-only binding to the contract
	AcrossTargetExecutorFilterer   // Log filterer for contract events
}

// AcrossTargetExecutorCaller is an auto generated read-only Go binding around an Ethereum contract.
type AcrossTargetExecutorCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AcrossTargetExecutorTransactor is an auto generated write-only Go binding around an Ethereum contract.
type AcrossTargetExecutorTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AcrossTargetExecutorFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type AcrossTargetExecutorFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AcrossTargetExecutorSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type AcrossTargetExecutorSession struct {
	Contract     *AcrossTargetExecutor // Generic contract binding to set the session for
	CallOpts     bind.CallOpts         // Call options to use throughout this session
	TransactOpts bind.TransactOpts     // Transaction auth options to use throughout this session
}

// AcrossTargetExecutorCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type AcrossTargetExecutorCallerSession struct {
	Contract *AcrossTargetExecutorCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts               // Call options to use throughout this session
}

// AcrossTargetExecutorTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type AcrossTargetExecutorTransactorSession struct {
	Contract     *AcrossTargetExecutorTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts               // Transaction auth options to use throughout this session
}

// AcrossTargetExecutorRaw is an auto generated low-level Go binding around an Ethereum contract.
type AcrossTargetExecutorRaw struct {
	Contract *AcrossTargetExecutor // Generic contract binding to access the raw methods on
}

// AcrossTargetExecutorCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type AcrossTargetExecutorCallerRaw struct {
	Contract *AcrossTargetExecutorCaller // Generic read-only contract binding to access the raw methods on
}

// AcrossTargetExecutorTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type AcrossTargetExecutorTransactorRaw struct {
	Contract *AcrossTargetExecutorTransactor // Generic write-only contract binding to access the raw methods on
}

// NewAcrossTargetExecutor creates a new instance of AcrossTargetExecutor, bound to a specific deployed contract.
func NewAcrossTargetExecutor(address common.Address, backend bind.ContractBackend) (*AcrossTargetExecutor, error) {
	contract, err := bindAcrossTargetExecutor(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &AcrossTargetExecutor{AcrossTargetExecutorCaller: AcrossTargetExecutorCaller{contract: contract}, AcrossTargetExecutorTransactor: AcrossTargetExecutorTransactor{contract: contract}, AcrossTargetExecutorFilterer: AcrossTargetExecutorFilterer{contract: contract}}, nil
}

// NewAcrossTargetExecutorCaller creates a new read-only instance of AcrossTargetExecutor, bound to a specific deployed contract.
func NewAcrossTargetExecutorCaller(address common.Address, caller bind.ContractCaller) (*AcrossTargetExecutorCaller, error) {
	contract, err := bindAcrossTargetExecutor(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &AcrossTargetExecutorCaller{contract: contract}, nil
}

// NewAcrossTargetExecutorTransactor creates a new write-only instance of AcrossTargetExecutor, bound to a specific deployed contract.
func NewAcrossTargetExecutorTransactor(address common.Address, transactor bind.ContractTransactor) (*AcrossTargetExecutorTransactor, error) {
	contract, err := bindAcrossTargetExecutor(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &AcrossTargetExecutorTransactor{contract: contract}, nil
}

// NewAcrossTargetExecutorFilterer creates a new log filterer instance of AcrossTargetExecutor, bound to a specific deployed contract.
func NewAcrossTargetExecutorFilterer(address common.Address, filterer bind.ContractFilterer) (*AcrossTargetExecutorFilterer, error) {
	contract, err := bindAcrossTargetExecutor(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &AcrossTargetExecutorFilterer{contract: contract}, nil
}

// bindAcrossTargetExecutor binds a generic wrapper to an already deployed contract.
func bindAcrossTargetExecutor(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := AcrossTargetExecutorMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_AcrossTargetExecutor *AcrossTargetExecutorRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _AcrossTargetExecutor.Contract.AcrossTargetExecutorCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_AcrossTargetExecutor *AcrossTargetExecutorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossTargetExecutor.Contract.AcrossTargetExecutorTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_AcrossTargetExecutor *AcrossTargetExecutorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _AcrossTargetExecutor.Contract.AcrossTargetExecutorTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_AcrossTargetExecutor *AcrossTargetExecutorCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _AcrossTargetExecutor.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_AcrossTargetExecutor *AcrossTargetExecutorTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossTargetExecutor.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_AcrossTargetExecutor *AcrossTargetExecutorTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _AcrossTargetExecutor.Contract.contract.Transact(opts, method, params...)
}

// AcrossSpokePool is a free data retrieval call binding the contract method 0x063820da.
//
// Solidity: function acrossSpokePool() view returns(address)
func (_AcrossTargetExecutor *AcrossTargetExecutorCaller) AcrossSpokePool(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossTargetExecutor.contract.Call(opts, &out, "acrossSpokePool")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AcrossSpokePool is a free data retrieval call binding the contract method 0x063820da.
//
// Solidity: function acrossSpokePool() view returns(address)
func (_AcrossTargetExecutor *AcrossTargetExecutorSession) AcrossSpokePool() (common.Address, error) {
	return _AcrossTargetExecutor.Contract.AcrossSpokePool(&_AcrossTargetExecutor.CallOpts)
}

// AcrossSpokePool is a free data retrieval call binding the contract method 0x063820da.
//
// Solidity: function acrossSpokePool() view returns(address)
func (_AcrossTargetExecutor *AcrossTargetExecutorCallerSession) AcrossSpokePool() (common.Address, error) {
	return _AcrossTargetExecutor.Contract.AcrossSpokePool(&_AcrossTargetExecutor.CallOpts)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_AcrossTargetExecutor *AcrossTargetExecutorCaller) IsInitialized(opts *bind.CallOpts, account common.Address) (bool, error) {
	var out []interface{}
	err := _AcrossTargetExecutor.contract.Call(opts, &out, "isInitialized", account)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_AcrossTargetExecutor *AcrossTargetExecutorSession) IsInitialized(account common.Address) (bool, error) {
	return _AcrossTargetExecutor.Contract.IsInitialized(&_AcrossTargetExecutor.CallOpts, account)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_AcrossTargetExecutor *AcrossTargetExecutorCallerSession) IsInitialized(account common.Address) (bool, error) {
	return _AcrossTargetExecutor.Contract.IsInitialized(&_AcrossTargetExecutor.CallOpts, account)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeID) pure returns(bool)
func (_AcrossTargetExecutor *AcrossTargetExecutorCaller) IsModuleType(opts *bind.CallOpts, typeID *big.Int) (bool, error) {
	var out []interface{}
	err := _AcrossTargetExecutor.contract.Call(opts, &out, "isModuleType", typeID)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeID) pure returns(bool)
func (_AcrossTargetExecutor *AcrossTargetExecutorSession) IsModuleType(typeID *big.Int) (bool, error) {
	return _AcrossTargetExecutor.Contract.IsModuleType(&_AcrossTargetExecutor.CallOpts, typeID)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeID) pure returns(bool)
func (_AcrossTargetExecutor *AcrossTargetExecutorCallerSession) IsModuleType(typeID *big.Int) (bool, error) {
	return _AcrossTargetExecutor.Contract.IsModuleType(&_AcrossTargetExecutor.CallOpts, typeID)
}

// LedgerConfiguration is a free data retrieval call binding the contract method 0x6740419b.
//
// Solidity: function ledgerConfiguration() view returns(address)
func (_AcrossTargetExecutor *AcrossTargetExecutorCaller) LedgerConfiguration(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossTargetExecutor.contract.Call(opts, &out, "ledgerConfiguration")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// LedgerConfiguration is a free data retrieval call binding the contract method 0x6740419b.
//
// Solidity: function ledgerConfiguration() view returns(address)
func (_AcrossTargetExecutor *AcrossTargetExecutorSession) LedgerConfiguration() (common.Address, error) {
	return _AcrossTargetExecutor.Contract.LedgerConfiguration(&_AcrossTargetExecutor.CallOpts)
}

// LedgerConfiguration is a free data retrieval call binding the contract method 0x6740419b.
//
// Solidity: function ledgerConfiguration() view returns(address)
func (_AcrossTargetExecutor *AcrossTargetExecutorCallerSession) LedgerConfiguration() (common.Address, error) {
	return _AcrossTargetExecutor.Contract.LedgerConfiguration(&_AcrossTargetExecutor.CallOpts)
}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() pure returns(string)
func (_AcrossTargetExecutor *AcrossTargetExecutorCaller) Name(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossTargetExecutor.contract.Call(opts, &out, "name")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() pure returns(string)
func (_AcrossTargetExecutor *AcrossTargetExecutorSession) Name() (string, error) {
	return _AcrossTargetExecutor.Contract.Name(&_AcrossTargetExecutor.CallOpts)
}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() pure returns(string)
func (_AcrossTargetExecutor *AcrossTargetExecutorCallerSession) Name() (string, error) {
	return _AcrossTargetExecutor.Contract.Name(&_AcrossTargetExecutor.CallOpts)
}

// NexusFactory is a free data retrieval call binding the contract method 0x73d070af.
//
// Solidity: function nexusFactory() view returns(address)
func (_AcrossTargetExecutor *AcrossTargetExecutorCaller) NexusFactory(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossTargetExecutor.contract.Call(opts, &out, "nexusFactory")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// NexusFactory is a free data retrieval call binding the contract method 0x73d070af.
//
// Solidity: function nexusFactory() view returns(address)
func (_AcrossTargetExecutor *AcrossTargetExecutorSession) NexusFactory() (common.Address, error) {
	return _AcrossTargetExecutor.Contract.NexusFactory(&_AcrossTargetExecutor.CallOpts)
}

// NexusFactory is a free data retrieval call binding the contract method 0x73d070af.
//
// Solidity: function nexusFactory() view returns(address)
func (_AcrossTargetExecutor *AcrossTargetExecutorCallerSession) NexusFactory() (common.Address, error) {
	return _AcrossTargetExecutor.Contract.NexusFactory(&_AcrossTargetExecutor.CallOpts)
}

// Nonces is a free data retrieval call binding the contract method 0x7ecebe00.
//
// Solidity: function nonces(address ) view returns(uint256)
func (_AcrossTargetExecutor *AcrossTargetExecutorCaller) Nonces(opts *bind.CallOpts, arg0 common.Address) (*big.Int, error) {
	var out []interface{}
	err := _AcrossTargetExecutor.contract.Call(opts, &out, "nonces", arg0)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// Nonces is a free data retrieval call binding the contract method 0x7ecebe00.
//
// Solidity: function nonces(address ) view returns(uint256)
func (_AcrossTargetExecutor *AcrossTargetExecutorSession) Nonces(arg0 common.Address) (*big.Int, error) {
	return _AcrossTargetExecutor.Contract.Nonces(&_AcrossTargetExecutor.CallOpts, arg0)
}

// Nonces is a free data retrieval call binding the contract method 0x7ecebe00.
//
// Solidity: function nonces(address ) view returns(uint256)
func (_AcrossTargetExecutor *AcrossTargetExecutorCallerSession) Nonces(arg0 common.Address) (*big.Int, error) {
	return _AcrossTargetExecutor.Contract.Nonces(&_AcrossTargetExecutor.CallOpts, arg0)
}

// SuperDestinationValidator is a free data retrieval call binding the contract method 0x4ddc738a.
//
// Solidity: function superDestinationValidator() view returns(address)
func (_AcrossTargetExecutor *AcrossTargetExecutorCaller) SuperDestinationValidator(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossTargetExecutor.contract.Call(opts, &out, "superDestinationValidator")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SuperDestinationValidator is a free data retrieval call binding the contract method 0x4ddc738a.
//
// Solidity: function superDestinationValidator() view returns(address)
func (_AcrossTargetExecutor *AcrossTargetExecutorSession) SuperDestinationValidator() (common.Address, error) {
	return _AcrossTargetExecutor.Contract.SuperDestinationValidator(&_AcrossTargetExecutor.CallOpts)
}

// SuperDestinationValidator is a free data retrieval call binding the contract method 0x4ddc738a.
//
// Solidity: function superDestinationValidator() view returns(address)
func (_AcrossTargetExecutor *AcrossTargetExecutorCallerSession) SuperDestinationValidator() (common.Address, error) {
	return _AcrossTargetExecutor.Contract.SuperDestinationValidator(&_AcrossTargetExecutor.CallOpts)
}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() pure returns(string)
func (_AcrossTargetExecutor *AcrossTargetExecutorCaller) Version(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _AcrossTargetExecutor.contract.Call(opts, &out, "version")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() pure returns(string)
func (_AcrossTargetExecutor *AcrossTargetExecutorSession) Version() (string, error) {
	return _AcrossTargetExecutor.Contract.Version(&_AcrossTargetExecutor.CallOpts)
}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() pure returns(string)
func (_AcrossTargetExecutor *AcrossTargetExecutorCallerSession) Version() (string, error) {
	return _AcrossTargetExecutor.Contract.Version(&_AcrossTargetExecutor.CallOpts)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_AcrossTargetExecutor *AcrossTargetExecutorTransactor) Execute(opts *bind.TransactOpts, data []byte) (*types.Transaction, error) {
	return _AcrossTargetExecutor.contract.Transact(opts, "execute", data)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_AcrossTargetExecutor *AcrossTargetExecutorSession) Execute(data []byte) (*types.Transaction, error) {
	return _AcrossTargetExecutor.Contract.Execute(&_AcrossTargetExecutor.TransactOpts, data)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_AcrossTargetExecutor *AcrossTargetExecutorTransactorSession) Execute(data []byte) (*types.Transaction, error) {
	return _AcrossTargetExecutor.Contract.Execute(&_AcrossTargetExecutor.TransactOpts, data)
}

// HandleV3AcrossMessage is a paid mutator transaction binding the contract method 0x3a5be8cb.
//
// Solidity: function handleV3AcrossMessage(address tokenSent, uint256 amount, address , bytes message) returns()
func (_AcrossTargetExecutor *AcrossTargetExecutorTransactor) HandleV3AcrossMessage(opts *bind.TransactOpts, tokenSent common.Address, amount *big.Int, arg2 common.Address, message []byte) (*types.Transaction, error) {
	return _AcrossTargetExecutor.contract.Transact(opts, "handleV3AcrossMessage", tokenSent, amount, arg2, message)
}

// HandleV3AcrossMessage is a paid mutator transaction binding the contract method 0x3a5be8cb.
//
// Solidity: function handleV3AcrossMessage(address tokenSent, uint256 amount, address , bytes message) returns()
func (_AcrossTargetExecutor *AcrossTargetExecutorSession) HandleV3AcrossMessage(tokenSent common.Address, amount *big.Int, arg2 common.Address, message []byte) (*types.Transaction, error) {
	return _AcrossTargetExecutor.Contract.HandleV3AcrossMessage(&_AcrossTargetExecutor.TransactOpts, tokenSent, amount, arg2, message)
}

// HandleV3AcrossMessage is a paid mutator transaction binding the contract method 0x3a5be8cb.
//
// Solidity: function handleV3AcrossMessage(address tokenSent, uint256 amount, address , bytes message) returns()
func (_AcrossTargetExecutor *AcrossTargetExecutorTransactorSession) HandleV3AcrossMessage(tokenSent common.Address, amount *big.Int, arg2 common.Address, message []byte) (*types.Transaction, error) {
	return _AcrossTargetExecutor.Contract.HandleV3AcrossMessage(&_AcrossTargetExecutor.TransactOpts, tokenSent, amount, arg2, message)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_AcrossTargetExecutor *AcrossTargetExecutorTransactor) OnInstall(opts *bind.TransactOpts, arg0 []byte) (*types.Transaction, error) {
	return _AcrossTargetExecutor.contract.Transact(opts, "onInstall", arg0)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_AcrossTargetExecutor *AcrossTargetExecutorSession) OnInstall(arg0 []byte) (*types.Transaction, error) {
	return _AcrossTargetExecutor.Contract.OnInstall(&_AcrossTargetExecutor.TransactOpts, arg0)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_AcrossTargetExecutor *AcrossTargetExecutorTransactorSession) OnInstall(arg0 []byte) (*types.Transaction, error) {
	return _AcrossTargetExecutor.Contract.OnInstall(&_AcrossTargetExecutor.TransactOpts, arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_AcrossTargetExecutor *AcrossTargetExecutorTransactor) OnUninstall(opts *bind.TransactOpts, arg0 []byte) (*types.Transaction, error) {
	return _AcrossTargetExecutor.contract.Transact(opts, "onUninstall", arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_AcrossTargetExecutor *AcrossTargetExecutorSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _AcrossTargetExecutor.Contract.OnUninstall(&_AcrossTargetExecutor.TransactOpts, arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_AcrossTargetExecutor *AcrossTargetExecutorTransactorSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _AcrossTargetExecutor.Contract.OnUninstall(&_AcrossTargetExecutor.TransactOpts, arg0)
}

// AcrossTargetExecutorAcrossFundsReceivedAndExecutedIterator is returned from FilterAcrossFundsReceivedAndExecuted and is used to iterate over the raw logs and unpacked data for AcrossFundsReceivedAndExecuted events raised by the AcrossTargetExecutor contract.
type AcrossTargetExecutorAcrossFundsReceivedAndExecutedIterator struct {
	Event *AcrossTargetExecutorAcrossFundsReceivedAndExecuted // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *AcrossTargetExecutorAcrossFundsReceivedAndExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossTargetExecutorAcrossFundsReceivedAndExecuted)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(AcrossTargetExecutorAcrossFundsReceivedAndExecuted)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *AcrossTargetExecutorAcrossFundsReceivedAndExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossTargetExecutorAcrossFundsReceivedAndExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossTargetExecutorAcrossFundsReceivedAndExecuted represents a AcrossFundsReceivedAndExecuted event raised by the AcrossTargetExecutor contract.
type AcrossTargetExecutorAcrossFundsReceivedAndExecuted struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAcrossFundsReceivedAndExecuted is a free log retrieval operation binding the contract event 0xd88a3ae4799f4e1c36d5e250d49c982bbcdc83d4ef55ed7fbfda5b201759e65f.
//
// Solidity: event AcrossFundsReceivedAndExecuted(address indexed account)
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) FilterAcrossFundsReceivedAndExecuted(opts *bind.FilterOpts, account []common.Address) (*AcrossTargetExecutorAcrossFundsReceivedAndExecutedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossTargetExecutor.contract.FilterLogs(opts, "AcrossFundsReceivedAndExecuted", accountRule)
	if err != nil {
		return nil, err
	}
	return &AcrossTargetExecutorAcrossFundsReceivedAndExecutedIterator{contract: _AcrossTargetExecutor.contract, event: "AcrossFundsReceivedAndExecuted", logs: logs, sub: sub}, nil
}

// WatchAcrossFundsReceivedAndExecuted is a free log subscription operation binding the contract event 0xd88a3ae4799f4e1c36d5e250d49c982bbcdc83d4ef55ed7fbfda5b201759e65f.
//
// Solidity: event AcrossFundsReceivedAndExecuted(address indexed account)
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) WatchAcrossFundsReceivedAndExecuted(opts *bind.WatchOpts, sink chan<- *AcrossTargetExecutorAcrossFundsReceivedAndExecuted, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossTargetExecutor.contract.WatchLogs(opts, "AcrossFundsReceivedAndExecuted", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossTargetExecutorAcrossFundsReceivedAndExecuted)
				if err := _AcrossTargetExecutor.contract.UnpackLog(event, "AcrossFundsReceivedAndExecuted", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseAcrossFundsReceivedAndExecuted is a log parse operation binding the contract event 0xd88a3ae4799f4e1c36d5e250d49c982bbcdc83d4ef55ed7fbfda5b201759e65f.
//
// Solidity: event AcrossFundsReceivedAndExecuted(address indexed account)
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) ParseAcrossFundsReceivedAndExecuted(log types.Log) (*AcrossTargetExecutorAcrossFundsReceivedAndExecuted, error) {
	event := new(AcrossTargetExecutorAcrossFundsReceivedAndExecuted)
	if err := _AcrossTargetExecutor.contract.UnpackLog(event, "AcrossFundsReceivedAndExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossTargetExecutorAcrossFundsReceivedButExecutionFailedIterator is returned from FilterAcrossFundsReceivedButExecutionFailed and is used to iterate over the raw logs and unpacked data for AcrossFundsReceivedButExecutionFailed events raised by the AcrossTargetExecutor contract.
type AcrossTargetExecutorAcrossFundsReceivedButExecutionFailedIterator struct {
	Event *AcrossTargetExecutorAcrossFundsReceivedButExecutionFailed // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *AcrossTargetExecutorAcrossFundsReceivedButExecutionFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossTargetExecutorAcrossFundsReceivedButExecutionFailed)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(AcrossTargetExecutorAcrossFundsReceivedButExecutionFailed)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *AcrossTargetExecutorAcrossFundsReceivedButExecutionFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossTargetExecutorAcrossFundsReceivedButExecutionFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossTargetExecutorAcrossFundsReceivedButExecutionFailed represents a AcrossFundsReceivedButExecutionFailed event raised by the AcrossTargetExecutor contract.
type AcrossTargetExecutorAcrossFundsReceivedButExecutionFailed struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAcrossFundsReceivedButExecutionFailed is a free log retrieval operation binding the contract event 0x04c138373117f58fea06058b5a537a58b5a5324f226667d219560baa728b609a.
//
// Solidity: event AcrossFundsReceivedButExecutionFailed(address indexed account)
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) FilterAcrossFundsReceivedButExecutionFailed(opts *bind.FilterOpts, account []common.Address) (*AcrossTargetExecutorAcrossFundsReceivedButExecutionFailedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossTargetExecutor.contract.FilterLogs(opts, "AcrossFundsReceivedButExecutionFailed", accountRule)
	if err != nil {
		return nil, err
	}
	return &AcrossTargetExecutorAcrossFundsReceivedButExecutionFailedIterator{contract: _AcrossTargetExecutor.contract, event: "AcrossFundsReceivedButExecutionFailed", logs: logs, sub: sub}, nil
}

// WatchAcrossFundsReceivedButExecutionFailed is a free log subscription operation binding the contract event 0x04c138373117f58fea06058b5a537a58b5a5324f226667d219560baa728b609a.
//
// Solidity: event AcrossFundsReceivedButExecutionFailed(address indexed account)
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) WatchAcrossFundsReceivedButExecutionFailed(opts *bind.WatchOpts, sink chan<- *AcrossTargetExecutorAcrossFundsReceivedButExecutionFailed, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossTargetExecutor.contract.WatchLogs(opts, "AcrossFundsReceivedButExecutionFailed", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossTargetExecutorAcrossFundsReceivedButExecutionFailed)
				if err := _AcrossTargetExecutor.contract.UnpackLog(event, "AcrossFundsReceivedButExecutionFailed", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseAcrossFundsReceivedButExecutionFailed is a log parse operation binding the contract event 0x04c138373117f58fea06058b5a537a58b5a5324f226667d219560baa728b609a.
//
// Solidity: event AcrossFundsReceivedButExecutionFailed(address indexed account)
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) ParseAcrossFundsReceivedButExecutionFailed(log types.Log) (*AcrossTargetExecutorAcrossFundsReceivedButExecutionFailed, error) {
	event := new(AcrossTargetExecutorAcrossFundsReceivedButExecutionFailed)
	if err := _AcrossTargetExecutor.contract.UnpackLog(event, "AcrossFundsReceivedButExecutionFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossTargetExecutorAcrossFundsReceivedButNotEnoughBalanceIterator is returned from FilterAcrossFundsReceivedButNotEnoughBalance and is used to iterate over the raw logs and unpacked data for AcrossFundsReceivedButNotEnoughBalance events raised by the AcrossTargetExecutor contract.
type AcrossTargetExecutorAcrossFundsReceivedButNotEnoughBalanceIterator struct {
	Event *AcrossTargetExecutorAcrossFundsReceivedButNotEnoughBalance // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *AcrossTargetExecutorAcrossFundsReceivedButNotEnoughBalanceIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossTargetExecutorAcrossFundsReceivedButNotEnoughBalance)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(AcrossTargetExecutorAcrossFundsReceivedButNotEnoughBalance)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *AcrossTargetExecutorAcrossFundsReceivedButNotEnoughBalanceIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossTargetExecutorAcrossFundsReceivedButNotEnoughBalanceIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossTargetExecutorAcrossFundsReceivedButNotEnoughBalance represents a AcrossFundsReceivedButNotEnoughBalance event raised by the AcrossTargetExecutor contract.
type AcrossTargetExecutorAcrossFundsReceivedButNotEnoughBalance struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAcrossFundsReceivedButNotEnoughBalance is a free log retrieval operation binding the contract event 0xb86165879c164ced5021b2b5c5c559281e991c7171a39df5b2699f900a9f3ebe.
//
// Solidity: event AcrossFundsReceivedButNotEnoughBalance(address indexed account)
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) FilterAcrossFundsReceivedButNotEnoughBalance(opts *bind.FilterOpts, account []common.Address) (*AcrossTargetExecutorAcrossFundsReceivedButNotEnoughBalanceIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossTargetExecutor.contract.FilterLogs(opts, "AcrossFundsReceivedButNotEnoughBalance", accountRule)
	if err != nil {
		return nil, err
	}
	return &AcrossTargetExecutorAcrossFundsReceivedButNotEnoughBalanceIterator{contract: _AcrossTargetExecutor.contract, event: "AcrossFundsReceivedButNotEnoughBalance", logs: logs, sub: sub}, nil
}

// WatchAcrossFundsReceivedButNotEnoughBalance is a free log subscription operation binding the contract event 0xb86165879c164ced5021b2b5c5c559281e991c7171a39df5b2699f900a9f3ebe.
//
// Solidity: event AcrossFundsReceivedButNotEnoughBalance(address indexed account)
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) WatchAcrossFundsReceivedButNotEnoughBalance(opts *bind.WatchOpts, sink chan<- *AcrossTargetExecutorAcrossFundsReceivedButNotEnoughBalance, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossTargetExecutor.contract.WatchLogs(opts, "AcrossFundsReceivedButNotEnoughBalance", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossTargetExecutorAcrossFundsReceivedButNotEnoughBalance)
				if err := _AcrossTargetExecutor.contract.UnpackLog(event, "AcrossFundsReceivedButNotEnoughBalance", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseAcrossFundsReceivedButNotEnoughBalance is a log parse operation binding the contract event 0xb86165879c164ced5021b2b5c5c559281e991c7171a39df5b2699f900a9f3ebe.
//
// Solidity: event AcrossFundsReceivedButNotEnoughBalance(address indexed account)
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) ParseAcrossFundsReceivedButNotEnoughBalance(log types.Log) (*AcrossTargetExecutorAcrossFundsReceivedButNotEnoughBalance, error) {
	event := new(AcrossTargetExecutorAcrossFundsReceivedButNotEnoughBalance)
	if err := _AcrossTargetExecutor.contract.UnpackLog(event, "AcrossFundsReceivedButNotEnoughBalance", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossTargetExecutorAcrossTargetExecutorExecutedIterator is returned from FilterAcrossTargetExecutorExecuted and is used to iterate over the raw logs and unpacked data for AcrossTargetExecutorExecuted events raised by the AcrossTargetExecutor contract.
type AcrossTargetExecutorAcrossTargetExecutorExecutedIterator struct {
	Event *AcrossTargetExecutorAcrossTargetExecutorExecuted // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *AcrossTargetExecutorAcrossTargetExecutorExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossTargetExecutorAcrossTargetExecutorExecuted)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(AcrossTargetExecutorAcrossTargetExecutorExecuted)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *AcrossTargetExecutorAcrossTargetExecutorExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossTargetExecutorAcrossTargetExecutorExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossTargetExecutorAcrossTargetExecutorExecuted represents a AcrossTargetExecutorExecuted event raised by the AcrossTargetExecutor contract.
type AcrossTargetExecutorAcrossTargetExecutorExecuted struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAcrossTargetExecutorExecuted is a free log retrieval operation binding the contract event 0x44ef3890256d36a141c9353ebec416eff129d0101c5feda8091dfe2e2a46f1cb.
//
// Solidity: event AcrossTargetExecutorExecuted(address indexed account)
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) FilterAcrossTargetExecutorExecuted(opts *bind.FilterOpts, account []common.Address) (*AcrossTargetExecutorAcrossTargetExecutorExecutedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossTargetExecutor.contract.FilterLogs(opts, "AcrossTargetExecutorExecuted", accountRule)
	if err != nil {
		return nil, err
	}
	return &AcrossTargetExecutorAcrossTargetExecutorExecutedIterator{contract: _AcrossTargetExecutor.contract, event: "AcrossTargetExecutorExecuted", logs: logs, sub: sub}, nil
}

// WatchAcrossTargetExecutorExecuted is a free log subscription operation binding the contract event 0x44ef3890256d36a141c9353ebec416eff129d0101c5feda8091dfe2e2a46f1cb.
//
// Solidity: event AcrossTargetExecutorExecuted(address indexed account)
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) WatchAcrossTargetExecutorExecuted(opts *bind.WatchOpts, sink chan<- *AcrossTargetExecutorAcrossTargetExecutorExecuted, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossTargetExecutor.contract.WatchLogs(opts, "AcrossTargetExecutorExecuted", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossTargetExecutorAcrossTargetExecutorExecuted)
				if err := _AcrossTargetExecutor.contract.UnpackLog(event, "AcrossTargetExecutorExecuted", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseAcrossTargetExecutorExecuted is a log parse operation binding the contract event 0x44ef3890256d36a141c9353ebec416eff129d0101c5feda8091dfe2e2a46f1cb.
//
// Solidity: event AcrossTargetExecutorExecuted(address indexed account)
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) ParseAcrossTargetExecutorExecuted(log types.Log) (*AcrossTargetExecutorAcrossTargetExecutorExecuted, error) {
	event := new(AcrossTargetExecutorAcrossTargetExecutorExecuted)
	if err := _AcrossTargetExecutor.contract.UnpackLog(event, "AcrossTargetExecutorExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossTargetExecutorAcrossTargetExecutorFailedIterator is returned from FilterAcrossTargetExecutorFailed and is used to iterate over the raw logs and unpacked data for AcrossTargetExecutorFailed events raised by the AcrossTargetExecutor contract.
type AcrossTargetExecutorAcrossTargetExecutorFailedIterator struct {
	Event *AcrossTargetExecutorAcrossTargetExecutorFailed // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *AcrossTargetExecutorAcrossTargetExecutorFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossTargetExecutorAcrossTargetExecutorFailed)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(AcrossTargetExecutorAcrossTargetExecutorFailed)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *AcrossTargetExecutorAcrossTargetExecutorFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossTargetExecutorAcrossTargetExecutorFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossTargetExecutorAcrossTargetExecutorFailed represents a AcrossTargetExecutorFailed event raised by the AcrossTargetExecutor contract.
type AcrossTargetExecutorAcrossTargetExecutorFailed struct {
	Reason string
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterAcrossTargetExecutorFailed is a free log retrieval operation binding the contract event 0x7d02e1c587c46cc20a8b5eafa434b01db8626003073b65fe37ec4b5572fabc49.
//
// Solidity: event AcrossTargetExecutorFailed(string reason)
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) FilterAcrossTargetExecutorFailed(opts *bind.FilterOpts) (*AcrossTargetExecutorAcrossTargetExecutorFailedIterator, error) {

	logs, sub, err := _AcrossTargetExecutor.contract.FilterLogs(opts, "AcrossTargetExecutorFailed")
	if err != nil {
		return nil, err
	}
	return &AcrossTargetExecutorAcrossTargetExecutorFailedIterator{contract: _AcrossTargetExecutor.contract, event: "AcrossTargetExecutorFailed", logs: logs, sub: sub}, nil
}

// WatchAcrossTargetExecutorFailed is a free log subscription operation binding the contract event 0x7d02e1c587c46cc20a8b5eafa434b01db8626003073b65fe37ec4b5572fabc49.
//
// Solidity: event AcrossTargetExecutorFailed(string reason)
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) WatchAcrossTargetExecutorFailed(opts *bind.WatchOpts, sink chan<- *AcrossTargetExecutorAcrossTargetExecutorFailed) (event.Subscription, error) {

	logs, sub, err := _AcrossTargetExecutor.contract.WatchLogs(opts, "AcrossTargetExecutorFailed")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossTargetExecutorAcrossTargetExecutorFailed)
				if err := _AcrossTargetExecutor.contract.UnpackLog(event, "AcrossTargetExecutorFailed", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseAcrossTargetExecutorFailed is a log parse operation binding the contract event 0x7d02e1c587c46cc20a8b5eafa434b01db8626003073b65fe37ec4b5572fabc49.
//
// Solidity: event AcrossTargetExecutorFailed(string reason)
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) ParseAcrossTargetExecutorFailed(log types.Log) (*AcrossTargetExecutorAcrossTargetExecutorFailed, error) {
	event := new(AcrossTargetExecutorAcrossTargetExecutorFailed)
	if err := _AcrossTargetExecutor.contract.UnpackLog(event, "AcrossTargetExecutorFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossTargetExecutorAcrossTargetExecutorFailedLowLevelIterator is returned from FilterAcrossTargetExecutorFailedLowLevel and is used to iterate over the raw logs and unpacked data for AcrossTargetExecutorFailedLowLevel events raised by the AcrossTargetExecutor contract.
type AcrossTargetExecutorAcrossTargetExecutorFailedLowLevelIterator struct {
	Event *AcrossTargetExecutorAcrossTargetExecutorFailedLowLevel // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *AcrossTargetExecutorAcrossTargetExecutorFailedLowLevelIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossTargetExecutorAcrossTargetExecutorFailedLowLevel)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(AcrossTargetExecutorAcrossTargetExecutorFailedLowLevel)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *AcrossTargetExecutorAcrossTargetExecutorFailedLowLevelIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossTargetExecutorAcrossTargetExecutorFailedLowLevelIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossTargetExecutorAcrossTargetExecutorFailedLowLevel represents a AcrossTargetExecutorFailedLowLevel event raised by the AcrossTargetExecutor contract.
type AcrossTargetExecutorAcrossTargetExecutorFailedLowLevel struct {
	LowLevelData []byte
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterAcrossTargetExecutorFailedLowLevel is a free log retrieval operation binding the contract event 0x6cf9fe6597e4a41bebd188c87a6104562338d36e972208ceb3160ea000797a5d.
//
// Solidity: event AcrossTargetExecutorFailedLowLevel(bytes lowLevelData)
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) FilterAcrossTargetExecutorFailedLowLevel(opts *bind.FilterOpts) (*AcrossTargetExecutorAcrossTargetExecutorFailedLowLevelIterator, error) {

	logs, sub, err := _AcrossTargetExecutor.contract.FilterLogs(opts, "AcrossTargetExecutorFailedLowLevel")
	if err != nil {
		return nil, err
	}
	return &AcrossTargetExecutorAcrossTargetExecutorFailedLowLevelIterator{contract: _AcrossTargetExecutor.contract, event: "AcrossTargetExecutorFailedLowLevel", logs: logs, sub: sub}, nil
}

// WatchAcrossTargetExecutorFailedLowLevel is a free log subscription operation binding the contract event 0x6cf9fe6597e4a41bebd188c87a6104562338d36e972208ceb3160ea000797a5d.
//
// Solidity: event AcrossTargetExecutorFailedLowLevel(bytes lowLevelData)
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) WatchAcrossTargetExecutorFailedLowLevel(opts *bind.WatchOpts, sink chan<- *AcrossTargetExecutorAcrossTargetExecutorFailedLowLevel) (event.Subscription, error) {

	logs, sub, err := _AcrossTargetExecutor.contract.WatchLogs(opts, "AcrossTargetExecutorFailedLowLevel")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossTargetExecutorAcrossTargetExecutorFailedLowLevel)
				if err := _AcrossTargetExecutor.contract.UnpackLog(event, "AcrossTargetExecutorFailedLowLevel", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseAcrossTargetExecutorFailedLowLevel is a log parse operation binding the contract event 0x6cf9fe6597e4a41bebd188c87a6104562338d36e972208ceb3160ea000797a5d.
//
// Solidity: event AcrossTargetExecutorFailedLowLevel(bytes lowLevelData)
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) ParseAcrossTargetExecutorFailedLowLevel(log types.Log) (*AcrossTargetExecutorAcrossTargetExecutorFailedLowLevel, error) {
	event := new(AcrossTargetExecutorAcrossTargetExecutorFailedLowLevel)
	if err := _AcrossTargetExecutor.contract.UnpackLog(event, "AcrossTargetExecutorFailedLowLevel", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossTargetExecutorAcrossTargetExecutorReceivedButNoHooksIterator is returned from FilterAcrossTargetExecutorReceivedButNoHooks and is used to iterate over the raw logs and unpacked data for AcrossTargetExecutorReceivedButNoHooks events raised by the AcrossTargetExecutor contract.
type AcrossTargetExecutorAcrossTargetExecutorReceivedButNoHooksIterator struct {
	Event *AcrossTargetExecutorAcrossTargetExecutorReceivedButNoHooks // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *AcrossTargetExecutorAcrossTargetExecutorReceivedButNoHooksIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossTargetExecutorAcrossTargetExecutorReceivedButNoHooks)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(AcrossTargetExecutorAcrossTargetExecutorReceivedButNoHooks)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *AcrossTargetExecutorAcrossTargetExecutorReceivedButNoHooksIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossTargetExecutorAcrossTargetExecutorReceivedButNoHooksIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossTargetExecutorAcrossTargetExecutorReceivedButNoHooks represents a AcrossTargetExecutorReceivedButNoHooks event raised by the AcrossTargetExecutor contract.
type AcrossTargetExecutorAcrossTargetExecutorReceivedButNoHooks struct {
	Raw types.Log // Blockchain specific contextual infos
}

// FilterAcrossTargetExecutorReceivedButNoHooks is a free log retrieval operation binding the contract event 0x2725b5feca9beaa093782ff894ab280e70f27e6ef59a7a0890b3900580db9adc.
//
// Solidity: event AcrossTargetExecutorReceivedButNoHooks()
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) FilterAcrossTargetExecutorReceivedButNoHooks(opts *bind.FilterOpts) (*AcrossTargetExecutorAcrossTargetExecutorReceivedButNoHooksIterator, error) {

	logs, sub, err := _AcrossTargetExecutor.contract.FilterLogs(opts, "AcrossTargetExecutorReceivedButNoHooks")
	if err != nil {
		return nil, err
	}
	return &AcrossTargetExecutorAcrossTargetExecutorReceivedButNoHooksIterator{contract: _AcrossTargetExecutor.contract, event: "AcrossTargetExecutorReceivedButNoHooks", logs: logs, sub: sub}, nil
}

// WatchAcrossTargetExecutorReceivedButNoHooks is a free log subscription operation binding the contract event 0x2725b5feca9beaa093782ff894ab280e70f27e6ef59a7a0890b3900580db9adc.
//
// Solidity: event AcrossTargetExecutorReceivedButNoHooks()
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) WatchAcrossTargetExecutorReceivedButNoHooks(opts *bind.WatchOpts, sink chan<- *AcrossTargetExecutorAcrossTargetExecutorReceivedButNoHooks) (event.Subscription, error) {

	logs, sub, err := _AcrossTargetExecutor.contract.WatchLogs(opts, "AcrossTargetExecutorReceivedButNoHooks")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossTargetExecutorAcrossTargetExecutorReceivedButNoHooks)
				if err := _AcrossTargetExecutor.contract.UnpackLog(event, "AcrossTargetExecutorReceivedButNoHooks", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseAcrossTargetExecutorReceivedButNoHooks is a log parse operation binding the contract event 0x2725b5feca9beaa093782ff894ab280e70f27e6ef59a7a0890b3900580db9adc.
//
// Solidity: event AcrossTargetExecutorReceivedButNoHooks()
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) ParseAcrossTargetExecutorReceivedButNoHooks(log types.Log) (*AcrossTargetExecutorAcrossTargetExecutorReceivedButNoHooks, error) {
	event := new(AcrossTargetExecutorAcrossTargetExecutorReceivedButNoHooks)
	if err := _AcrossTargetExecutor.contract.UnpackLog(event, "AcrossTargetExecutorReceivedButNoHooks", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossTargetExecutorAcrossTargetExecutorReceivedButNotEnoughBalanceIterator is returned from FilterAcrossTargetExecutorReceivedButNotEnoughBalance and is used to iterate over the raw logs and unpacked data for AcrossTargetExecutorReceivedButNotEnoughBalance events raised by the AcrossTargetExecutor contract.
type AcrossTargetExecutorAcrossTargetExecutorReceivedButNotEnoughBalanceIterator struct {
	Event *AcrossTargetExecutorAcrossTargetExecutorReceivedButNotEnoughBalance // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *AcrossTargetExecutorAcrossTargetExecutorReceivedButNotEnoughBalanceIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossTargetExecutorAcrossTargetExecutorReceivedButNotEnoughBalance)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(AcrossTargetExecutorAcrossTargetExecutorReceivedButNotEnoughBalance)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *AcrossTargetExecutorAcrossTargetExecutorReceivedButNotEnoughBalanceIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossTargetExecutorAcrossTargetExecutorReceivedButNotEnoughBalanceIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossTargetExecutorAcrossTargetExecutorReceivedButNotEnoughBalance represents a AcrossTargetExecutorReceivedButNotEnoughBalance event raised by the AcrossTargetExecutor contract.
type AcrossTargetExecutorAcrossTargetExecutorReceivedButNotEnoughBalance struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAcrossTargetExecutorReceivedButNotEnoughBalance is a free log retrieval operation binding the contract event 0x2fb56def33ed49324410b2b3fa6617f94f22085dbddaba5fd2ca22dcd2390798.
//
// Solidity: event AcrossTargetExecutorReceivedButNotEnoughBalance(address indexed account)
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) FilterAcrossTargetExecutorReceivedButNotEnoughBalance(opts *bind.FilterOpts, account []common.Address) (*AcrossTargetExecutorAcrossTargetExecutorReceivedButNotEnoughBalanceIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossTargetExecutor.contract.FilterLogs(opts, "AcrossTargetExecutorReceivedButNotEnoughBalance", accountRule)
	if err != nil {
		return nil, err
	}
	return &AcrossTargetExecutorAcrossTargetExecutorReceivedButNotEnoughBalanceIterator{contract: _AcrossTargetExecutor.contract, event: "AcrossTargetExecutorReceivedButNotEnoughBalance", logs: logs, sub: sub}, nil
}

// WatchAcrossTargetExecutorReceivedButNotEnoughBalance is a free log subscription operation binding the contract event 0x2fb56def33ed49324410b2b3fa6617f94f22085dbddaba5fd2ca22dcd2390798.
//
// Solidity: event AcrossTargetExecutorReceivedButNotEnoughBalance(address indexed account)
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) WatchAcrossTargetExecutorReceivedButNotEnoughBalance(opts *bind.WatchOpts, sink chan<- *AcrossTargetExecutorAcrossTargetExecutorReceivedButNotEnoughBalance, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossTargetExecutor.contract.WatchLogs(opts, "AcrossTargetExecutorReceivedButNotEnoughBalance", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossTargetExecutorAcrossTargetExecutorReceivedButNotEnoughBalance)
				if err := _AcrossTargetExecutor.contract.UnpackLog(event, "AcrossTargetExecutorReceivedButNotEnoughBalance", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseAcrossTargetExecutorReceivedButNotEnoughBalance is a log parse operation binding the contract event 0x2fb56def33ed49324410b2b3fa6617f94f22085dbddaba5fd2ca22dcd2390798.
//
// Solidity: event AcrossTargetExecutorReceivedButNotEnoughBalance(address indexed account)
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) ParseAcrossTargetExecutorReceivedButNotEnoughBalance(log types.Log) (*AcrossTargetExecutorAcrossTargetExecutorReceivedButNotEnoughBalance, error) {
	event := new(AcrossTargetExecutorAcrossTargetExecutorReceivedButNotEnoughBalance)
	if err := _AcrossTargetExecutor.contract.UnpackLog(event, "AcrossTargetExecutorReceivedButNotEnoughBalance", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossTargetExecutorSuperPositionLockedIterator is returned from FilterSuperPositionLocked and is used to iterate over the raw logs and unpacked data for SuperPositionLocked events raised by the AcrossTargetExecutor contract.
type AcrossTargetExecutorSuperPositionLockedIterator struct {
	Event *AcrossTargetExecutorSuperPositionLocked // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *AcrossTargetExecutorSuperPositionLockedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossTargetExecutorSuperPositionLocked)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(AcrossTargetExecutorSuperPositionLocked)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *AcrossTargetExecutorSuperPositionLockedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossTargetExecutorSuperPositionLockedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossTargetExecutorSuperPositionLocked represents a SuperPositionLocked event raised by the AcrossTargetExecutor contract.
type AcrossTargetExecutorSuperPositionLocked struct {
	Account common.Address
	SpToken common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterSuperPositionLocked is a free log retrieval operation binding the contract event 0xdf09bac395df649ca72fb3ffb451d40c290e25dcef3002e19d2c04ce09441b9b.
//
// Solidity: event SuperPositionLocked(address indexed account, address indexed spToken, uint256 amount)
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) FilterSuperPositionLocked(opts *bind.FilterOpts, account []common.Address, spToken []common.Address) (*AcrossTargetExecutorSuperPositionLockedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var spTokenRule []interface{}
	for _, spTokenItem := range spToken {
		spTokenRule = append(spTokenRule, spTokenItem)
	}

	logs, sub, err := _AcrossTargetExecutor.contract.FilterLogs(opts, "SuperPositionLocked", accountRule, spTokenRule)
	if err != nil {
		return nil, err
	}
	return &AcrossTargetExecutorSuperPositionLockedIterator{contract: _AcrossTargetExecutor.contract, event: "SuperPositionLocked", logs: logs, sub: sub}, nil
}

// WatchSuperPositionLocked is a free log subscription operation binding the contract event 0xdf09bac395df649ca72fb3ffb451d40c290e25dcef3002e19d2c04ce09441b9b.
//
// Solidity: event SuperPositionLocked(address indexed account, address indexed spToken, uint256 amount)
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) WatchSuperPositionLocked(opts *bind.WatchOpts, sink chan<- *AcrossTargetExecutorSuperPositionLocked, account []common.Address, spToken []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var spTokenRule []interface{}
	for _, spTokenItem := range spToken {
		spTokenRule = append(spTokenRule, spTokenItem)
	}

	logs, sub, err := _AcrossTargetExecutor.contract.WatchLogs(opts, "SuperPositionLocked", accountRule, spTokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossTargetExecutorSuperPositionLocked)
				if err := _AcrossTargetExecutor.contract.UnpackLog(event, "SuperPositionLocked", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseSuperPositionLocked is a log parse operation binding the contract event 0xdf09bac395df649ca72fb3ffb451d40c290e25dcef3002e19d2c04ce09441b9b.
//
// Solidity: event SuperPositionLocked(address indexed account, address indexed spToken, uint256 amount)
func (_AcrossTargetExecutor *AcrossTargetExecutorFilterer) ParseSuperPositionLocked(log types.Log) (*AcrossTargetExecutorSuperPositionLocked, error) {
	event := new(AcrossTargetExecutorSuperPositionLocked)
	if err := _AcrossTargetExecutor.contract.UnpackLog(event, "SuperPositionLocked", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
