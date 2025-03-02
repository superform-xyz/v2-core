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

// PeripheryRegistryMetaData contains all meta data concerning the PeripheryRegistry contract.
var PeripheryRegistryMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"owner_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"treasury_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"executeFeeSplitUpdate\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"getRegisteredHooks\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getSuperformFeeSplit\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTreasury\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isHookRegistered\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proposeFeeSplit\",\"inputs\":[{\"name\":\"feeSplit_\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"registerHook\",\"inputs\":[{\"name\":\"hook_\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"registeredHooks\",\"inputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setTreasury\",\"inputs\":[{\"name\":\"treasury_\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unregisterHook\",\"inputs\":[{\"name\":\"hook_\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"FeeSplitProposed\",\"inputs\":[{\"name\":\"superformFeeSplit\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"effectiveTime\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"FeeSplitUpdated\",\"inputs\":[{\"name\":\"superformFeeSplit\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"HookRegistered\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"HookUnregistered\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TreasuryUpdated\",\"inputs\":[{\"name\":\"treasury\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"HOOK_ALREADY_REGISTERED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"HOOK_NOT_REGISTERED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_ACCOUNT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_FEE_SPLIT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_AUTHORIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"OwnableInvalidOwner\",\"inputs\":[{\"name\":\"owner\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"OwnableUnauthorizedAccount\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"TIMELOCK_NOT_EXPIRED\",\"inputs\":[]}]",
}

// PeripheryRegistryABI is the input ABI used to generate the binding from.
// Deprecated: Use PeripheryRegistryMetaData.ABI instead.
var PeripheryRegistryABI = PeripheryRegistryMetaData.ABI

// PeripheryRegistry is an auto generated Go binding around an Ethereum contract.
type PeripheryRegistry struct {
	PeripheryRegistryCaller     // Read-only binding to the contract
	PeripheryRegistryTransactor // Write-only binding to the contract
	PeripheryRegistryFilterer   // Log filterer for contract events
}

// PeripheryRegistryCaller is an auto generated read-only Go binding around an Ethereum contract.
type PeripheryRegistryCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// PeripheryRegistryTransactor is an auto generated write-only Go binding around an Ethereum contract.
type PeripheryRegistryTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// PeripheryRegistryFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type PeripheryRegistryFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// PeripheryRegistrySession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type PeripheryRegistrySession struct {
	Contract     *PeripheryRegistry // Generic contract binding to set the session for
	CallOpts     bind.CallOpts      // Call options to use throughout this session
	TransactOpts bind.TransactOpts  // Transaction auth options to use throughout this session
}

// PeripheryRegistryCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type PeripheryRegistryCallerSession struct {
	Contract *PeripheryRegistryCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts            // Call options to use throughout this session
}

// PeripheryRegistryTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type PeripheryRegistryTransactorSession struct {
	Contract     *PeripheryRegistryTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts            // Transaction auth options to use throughout this session
}

// PeripheryRegistryRaw is an auto generated low-level Go binding around an Ethereum contract.
type PeripheryRegistryRaw struct {
	Contract *PeripheryRegistry // Generic contract binding to access the raw methods on
}

// PeripheryRegistryCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type PeripheryRegistryCallerRaw struct {
	Contract *PeripheryRegistryCaller // Generic read-only contract binding to access the raw methods on
}

// PeripheryRegistryTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type PeripheryRegistryTransactorRaw struct {
	Contract *PeripheryRegistryTransactor // Generic write-only contract binding to access the raw methods on
}

// NewPeripheryRegistry creates a new instance of PeripheryRegistry, bound to a specific deployed contract.
func NewPeripheryRegistry(address common.Address, backend bind.ContractBackend) (*PeripheryRegistry, error) {
	contract, err := bindPeripheryRegistry(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &PeripheryRegistry{PeripheryRegistryCaller: PeripheryRegistryCaller{contract: contract}, PeripheryRegistryTransactor: PeripheryRegistryTransactor{contract: contract}, PeripheryRegistryFilterer: PeripheryRegistryFilterer{contract: contract}}, nil
}

// NewPeripheryRegistryCaller creates a new read-only instance of PeripheryRegistry, bound to a specific deployed contract.
func NewPeripheryRegistryCaller(address common.Address, caller bind.ContractCaller) (*PeripheryRegistryCaller, error) {
	contract, err := bindPeripheryRegistry(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &PeripheryRegistryCaller{contract: contract}, nil
}

// NewPeripheryRegistryTransactor creates a new write-only instance of PeripheryRegistry, bound to a specific deployed contract.
func NewPeripheryRegistryTransactor(address common.Address, transactor bind.ContractTransactor) (*PeripheryRegistryTransactor, error) {
	contract, err := bindPeripheryRegistry(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &PeripheryRegistryTransactor{contract: contract}, nil
}

// NewPeripheryRegistryFilterer creates a new log filterer instance of PeripheryRegistry, bound to a specific deployed contract.
func NewPeripheryRegistryFilterer(address common.Address, filterer bind.ContractFilterer) (*PeripheryRegistryFilterer, error) {
	contract, err := bindPeripheryRegistry(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &PeripheryRegistryFilterer{contract: contract}, nil
}

// bindPeripheryRegistry binds a generic wrapper to an already deployed contract.
func bindPeripheryRegistry(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := PeripheryRegistryMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_PeripheryRegistry *PeripheryRegistryRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _PeripheryRegistry.Contract.PeripheryRegistryCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_PeripheryRegistry *PeripheryRegistryRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _PeripheryRegistry.Contract.PeripheryRegistryTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_PeripheryRegistry *PeripheryRegistryRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _PeripheryRegistry.Contract.PeripheryRegistryTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_PeripheryRegistry *PeripheryRegistryCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _PeripheryRegistry.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_PeripheryRegistry *PeripheryRegistryTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _PeripheryRegistry.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_PeripheryRegistry *PeripheryRegistryTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _PeripheryRegistry.Contract.contract.Transact(opts, method, params...)
}

// GetRegisteredHooks is a free data retrieval call binding the contract method 0x841b0175.
//
// Solidity: function getRegisteredHooks() view returns(address[])
func (_PeripheryRegistry *PeripheryRegistryCaller) GetRegisteredHooks(opts *bind.CallOpts) ([]common.Address, error) {
	var out []interface{}
	err := _PeripheryRegistry.contract.Call(opts, &out, "getRegisteredHooks")

	if err != nil {
		return *new([]common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new([]common.Address)).(*[]common.Address)

	return out0, err

}

// GetRegisteredHooks is a free data retrieval call binding the contract method 0x841b0175.
//
// Solidity: function getRegisteredHooks() view returns(address[])
func (_PeripheryRegistry *PeripheryRegistrySession) GetRegisteredHooks() ([]common.Address, error) {
	return _PeripheryRegistry.Contract.GetRegisteredHooks(&_PeripheryRegistry.CallOpts)
}

// GetRegisteredHooks is a free data retrieval call binding the contract method 0x841b0175.
//
// Solidity: function getRegisteredHooks() view returns(address[])
func (_PeripheryRegistry *PeripheryRegistryCallerSession) GetRegisteredHooks() ([]common.Address, error) {
	return _PeripheryRegistry.Contract.GetRegisteredHooks(&_PeripheryRegistry.CallOpts)
}

// GetSuperformFeeSplit is a free data retrieval call binding the contract method 0x666854af.
//
// Solidity: function getSuperformFeeSplit() view returns(uint256)
func (_PeripheryRegistry *PeripheryRegistryCaller) GetSuperformFeeSplit(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _PeripheryRegistry.contract.Call(opts, &out, "getSuperformFeeSplit")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetSuperformFeeSplit is a free data retrieval call binding the contract method 0x666854af.
//
// Solidity: function getSuperformFeeSplit() view returns(uint256)
func (_PeripheryRegistry *PeripheryRegistrySession) GetSuperformFeeSplit() (*big.Int, error) {
	return _PeripheryRegistry.Contract.GetSuperformFeeSplit(&_PeripheryRegistry.CallOpts)
}

// GetSuperformFeeSplit is a free data retrieval call binding the contract method 0x666854af.
//
// Solidity: function getSuperformFeeSplit() view returns(uint256)
func (_PeripheryRegistry *PeripheryRegistryCallerSession) GetSuperformFeeSplit() (*big.Int, error) {
	return _PeripheryRegistry.Contract.GetSuperformFeeSplit(&_PeripheryRegistry.CallOpts)
}

// GetTreasury is a free data retrieval call binding the contract method 0x3b19e84a.
//
// Solidity: function getTreasury() view returns(address)
func (_PeripheryRegistry *PeripheryRegistryCaller) GetTreasury(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _PeripheryRegistry.contract.Call(opts, &out, "getTreasury")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetTreasury is a free data retrieval call binding the contract method 0x3b19e84a.
//
// Solidity: function getTreasury() view returns(address)
func (_PeripheryRegistry *PeripheryRegistrySession) GetTreasury() (common.Address, error) {
	return _PeripheryRegistry.Contract.GetTreasury(&_PeripheryRegistry.CallOpts)
}

// GetTreasury is a free data retrieval call binding the contract method 0x3b19e84a.
//
// Solidity: function getTreasury() view returns(address)
func (_PeripheryRegistry *PeripheryRegistryCallerSession) GetTreasury() (common.Address, error) {
	return _PeripheryRegistry.Contract.GetTreasury(&_PeripheryRegistry.CallOpts)
}

// IsHookRegistered is a free data retrieval call binding the contract method 0x0cbad00c.
//
// Solidity: function isHookRegistered(address ) view returns(bool)
func (_PeripheryRegistry *PeripheryRegistryCaller) IsHookRegistered(opts *bind.CallOpts, arg0 common.Address) (bool, error) {
	var out []interface{}
	err := _PeripheryRegistry.contract.Call(opts, &out, "isHookRegistered", arg0)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsHookRegistered is a free data retrieval call binding the contract method 0x0cbad00c.
//
// Solidity: function isHookRegistered(address ) view returns(bool)
func (_PeripheryRegistry *PeripheryRegistrySession) IsHookRegistered(arg0 common.Address) (bool, error) {
	return _PeripheryRegistry.Contract.IsHookRegistered(&_PeripheryRegistry.CallOpts, arg0)
}

// IsHookRegistered is a free data retrieval call binding the contract method 0x0cbad00c.
//
// Solidity: function isHookRegistered(address ) view returns(bool)
func (_PeripheryRegistry *PeripheryRegistryCallerSession) IsHookRegistered(arg0 common.Address) (bool, error) {
	return _PeripheryRegistry.Contract.IsHookRegistered(&_PeripheryRegistry.CallOpts, arg0)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_PeripheryRegistry *PeripheryRegistryCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _PeripheryRegistry.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_PeripheryRegistry *PeripheryRegistrySession) Owner() (common.Address, error) {
	return _PeripheryRegistry.Contract.Owner(&_PeripheryRegistry.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_PeripheryRegistry *PeripheryRegistryCallerSession) Owner() (common.Address, error) {
	return _PeripheryRegistry.Contract.Owner(&_PeripheryRegistry.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_PeripheryRegistry *PeripheryRegistryCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _PeripheryRegistry.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_PeripheryRegistry *PeripheryRegistrySession) PendingOwner() (common.Address, error) {
	return _PeripheryRegistry.Contract.PendingOwner(&_PeripheryRegistry.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_PeripheryRegistry *PeripheryRegistryCallerSession) PendingOwner() (common.Address, error) {
	return _PeripheryRegistry.Contract.PendingOwner(&_PeripheryRegistry.CallOpts)
}

// RegisteredHooks is a free data retrieval call binding the contract method 0xc754336c.
//
// Solidity: function registeredHooks(uint256 ) view returns(address)
func (_PeripheryRegistry *PeripheryRegistryCaller) RegisteredHooks(opts *bind.CallOpts, arg0 *big.Int) (common.Address, error) {
	var out []interface{}
	err := _PeripheryRegistry.contract.Call(opts, &out, "registeredHooks", arg0)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// RegisteredHooks is a free data retrieval call binding the contract method 0xc754336c.
//
// Solidity: function registeredHooks(uint256 ) view returns(address)
func (_PeripheryRegistry *PeripheryRegistrySession) RegisteredHooks(arg0 *big.Int) (common.Address, error) {
	return _PeripheryRegistry.Contract.RegisteredHooks(&_PeripheryRegistry.CallOpts, arg0)
}

// RegisteredHooks is a free data retrieval call binding the contract method 0xc754336c.
//
// Solidity: function registeredHooks(uint256 ) view returns(address)
func (_PeripheryRegistry *PeripheryRegistryCallerSession) RegisteredHooks(arg0 *big.Int) (common.Address, error) {
	return _PeripheryRegistry.Contract.RegisteredHooks(&_PeripheryRegistry.CallOpts, arg0)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_PeripheryRegistry *PeripheryRegistryTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _PeripheryRegistry.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_PeripheryRegistry *PeripheryRegistrySession) AcceptOwnership() (*types.Transaction, error) {
	return _PeripheryRegistry.Contract.AcceptOwnership(&_PeripheryRegistry.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_PeripheryRegistry *PeripheryRegistryTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _PeripheryRegistry.Contract.AcceptOwnership(&_PeripheryRegistry.TransactOpts)
}

// ExecuteFeeSplitUpdate is a paid mutator transaction binding the contract method 0x1b9bc28b.
//
// Solidity: function executeFeeSplitUpdate() returns()
func (_PeripheryRegistry *PeripheryRegistryTransactor) ExecuteFeeSplitUpdate(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _PeripheryRegistry.contract.Transact(opts, "executeFeeSplitUpdate")
}

// ExecuteFeeSplitUpdate is a paid mutator transaction binding the contract method 0x1b9bc28b.
//
// Solidity: function executeFeeSplitUpdate() returns()
func (_PeripheryRegistry *PeripheryRegistrySession) ExecuteFeeSplitUpdate() (*types.Transaction, error) {
	return _PeripheryRegistry.Contract.ExecuteFeeSplitUpdate(&_PeripheryRegistry.TransactOpts)
}

// ExecuteFeeSplitUpdate is a paid mutator transaction binding the contract method 0x1b9bc28b.
//
// Solidity: function executeFeeSplitUpdate() returns()
func (_PeripheryRegistry *PeripheryRegistryTransactorSession) ExecuteFeeSplitUpdate() (*types.Transaction, error) {
	return _PeripheryRegistry.Contract.ExecuteFeeSplitUpdate(&_PeripheryRegistry.TransactOpts)
}

// ProposeFeeSplit is a paid mutator transaction binding the contract method 0x9daa6600.
//
// Solidity: function proposeFeeSplit(uint256 feeSplit_) returns()
func (_PeripheryRegistry *PeripheryRegistryTransactor) ProposeFeeSplit(opts *bind.TransactOpts, feeSplit_ *big.Int) (*types.Transaction, error) {
	return _PeripheryRegistry.contract.Transact(opts, "proposeFeeSplit", feeSplit_)
}

// ProposeFeeSplit is a paid mutator transaction binding the contract method 0x9daa6600.
//
// Solidity: function proposeFeeSplit(uint256 feeSplit_) returns()
func (_PeripheryRegistry *PeripheryRegistrySession) ProposeFeeSplit(feeSplit_ *big.Int) (*types.Transaction, error) {
	return _PeripheryRegistry.Contract.ProposeFeeSplit(&_PeripheryRegistry.TransactOpts, feeSplit_)
}

// ProposeFeeSplit is a paid mutator transaction binding the contract method 0x9daa6600.
//
// Solidity: function proposeFeeSplit(uint256 feeSplit_) returns()
func (_PeripheryRegistry *PeripheryRegistryTransactorSession) ProposeFeeSplit(feeSplit_ *big.Int) (*types.Transaction, error) {
	return _PeripheryRegistry.Contract.ProposeFeeSplit(&_PeripheryRegistry.TransactOpts, feeSplit_)
}

// RegisterHook is a paid mutator transaction binding the contract method 0x6354b661.
//
// Solidity: function registerHook(address hook_) returns()
func (_PeripheryRegistry *PeripheryRegistryTransactor) RegisterHook(opts *bind.TransactOpts, hook_ common.Address) (*types.Transaction, error) {
	return _PeripheryRegistry.contract.Transact(opts, "registerHook", hook_)
}

// RegisterHook is a paid mutator transaction binding the contract method 0x6354b661.
//
// Solidity: function registerHook(address hook_) returns()
func (_PeripheryRegistry *PeripheryRegistrySession) RegisterHook(hook_ common.Address) (*types.Transaction, error) {
	return _PeripheryRegistry.Contract.RegisterHook(&_PeripheryRegistry.TransactOpts, hook_)
}

// RegisterHook is a paid mutator transaction binding the contract method 0x6354b661.
//
// Solidity: function registerHook(address hook_) returns()
func (_PeripheryRegistry *PeripheryRegistryTransactorSession) RegisterHook(hook_ common.Address) (*types.Transaction, error) {
	return _PeripheryRegistry.Contract.RegisterHook(&_PeripheryRegistry.TransactOpts, hook_)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_PeripheryRegistry *PeripheryRegistryTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _PeripheryRegistry.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_PeripheryRegistry *PeripheryRegistrySession) RenounceOwnership() (*types.Transaction, error) {
	return _PeripheryRegistry.Contract.RenounceOwnership(&_PeripheryRegistry.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_PeripheryRegistry *PeripheryRegistryTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _PeripheryRegistry.Contract.RenounceOwnership(&_PeripheryRegistry.TransactOpts)
}

// SetTreasury is a paid mutator transaction binding the contract method 0xf0f44260.
//
// Solidity: function setTreasury(address treasury_) returns()
func (_PeripheryRegistry *PeripheryRegistryTransactor) SetTreasury(opts *bind.TransactOpts, treasury_ common.Address) (*types.Transaction, error) {
	return _PeripheryRegistry.contract.Transact(opts, "setTreasury", treasury_)
}

// SetTreasury is a paid mutator transaction binding the contract method 0xf0f44260.
//
// Solidity: function setTreasury(address treasury_) returns()
func (_PeripheryRegistry *PeripheryRegistrySession) SetTreasury(treasury_ common.Address) (*types.Transaction, error) {
	return _PeripheryRegistry.Contract.SetTreasury(&_PeripheryRegistry.TransactOpts, treasury_)
}

// SetTreasury is a paid mutator transaction binding the contract method 0xf0f44260.
//
// Solidity: function setTreasury(address treasury_) returns()
func (_PeripheryRegistry *PeripheryRegistryTransactorSession) SetTreasury(treasury_ common.Address) (*types.Transaction, error) {
	return _PeripheryRegistry.Contract.SetTreasury(&_PeripheryRegistry.TransactOpts, treasury_)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_PeripheryRegistry *PeripheryRegistryTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _PeripheryRegistry.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_PeripheryRegistry *PeripheryRegistrySession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _PeripheryRegistry.Contract.TransferOwnership(&_PeripheryRegistry.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_PeripheryRegistry *PeripheryRegistryTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _PeripheryRegistry.Contract.TransferOwnership(&_PeripheryRegistry.TransactOpts, newOwner)
}

// UnregisterHook is a paid mutator transaction binding the contract method 0xf76f48cb.
//
// Solidity: function unregisterHook(address hook_) returns()
func (_PeripheryRegistry *PeripheryRegistryTransactor) UnregisterHook(opts *bind.TransactOpts, hook_ common.Address) (*types.Transaction, error) {
	return _PeripheryRegistry.contract.Transact(opts, "unregisterHook", hook_)
}

// UnregisterHook is a paid mutator transaction binding the contract method 0xf76f48cb.
//
// Solidity: function unregisterHook(address hook_) returns()
func (_PeripheryRegistry *PeripheryRegistrySession) UnregisterHook(hook_ common.Address) (*types.Transaction, error) {
	return _PeripheryRegistry.Contract.UnregisterHook(&_PeripheryRegistry.TransactOpts, hook_)
}

// UnregisterHook is a paid mutator transaction binding the contract method 0xf76f48cb.
//
// Solidity: function unregisterHook(address hook_) returns()
func (_PeripheryRegistry *PeripheryRegistryTransactorSession) UnregisterHook(hook_ common.Address) (*types.Transaction, error) {
	return _PeripheryRegistry.Contract.UnregisterHook(&_PeripheryRegistry.TransactOpts, hook_)
}

// PeripheryRegistryFeeSplitProposedIterator is returned from FilterFeeSplitProposed and is used to iterate over the raw logs and unpacked data for FeeSplitProposed events raised by the PeripheryRegistry contract.
type PeripheryRegistryFeeSplitProposedIterator struct {
	Event *PeripheryRegistryFeeSplitProposed // Event containing the contract specifics and raw log

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
func (it *PeripheryRegistryFeeSplitProposedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PeripheryRegistryFeeSplitProposed)
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
		it.Event = new(PeripheryRegistryFeeSplitProposed)
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
func (it *PeripheryRegistryFeeSplitProposedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PeripheryRegistryFeeSplitProposedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PeripheryRegistryFeeSplitProposed represents a FeeSplitProposed event raised by the PeripheryRegistry contract.
type PeripheryRegistryFeeSplitProposed struct {
	SuperformFeeSplit *big.Int
	EffectiveTime     *big.Int
	Raw               types.Log // Blockchain specific contextual infos
}

// FilterFeeSplitProposed is a free log retrieval operation binding the contract event 0x33f6ffd7ef6e2fbeec2756d83bf09809997101b62f86ef82fa0169570eee5cb5.
//
// Solidity: event FeeSplitProposed(uint256 superformFeeSplit, uint256 effectiveTime)
func (_PeripheryRegistry *PeripheryRegistryFilterer) FilterFeeSplitProposed(opts *bind.FilterOpts) (*PeripheryRegistryFeeSplitProposedIterator, error) {

	logs, sub, err := _PeripheryRegistry.contract.FilterLogs(opts, "FeeSplitProposed")
	if err != nil {
		return nil, err
	}
	return &PeripheryRegistryFeeSplitProposedIterator{contract: _PeripheryRegistry.contract, event: "FeeSplitProposed", logs: logs, sub: sub}, nil
}

// WatchFeeSplitProposed is a free log subscription operation binding the contract event 0x33f6ffd7ef6e2fbeec2756d83bf09809997101b62f86ef82fa0169570eee5cb5.
//
// Solidity: event FeeSplitProposed(uint256 superformFeeSplit, uint256 effectiveTime)
func (_PeripheryRegistry *PeripheryRegistryFilterer) WatchFeeSplitProposed(opts *bind.WatchOpts, sink chan<- *PeripheryRegistryFeeSplitProposed) (event.Subscription, error) {

	logs, sub, err := _PeripheryRegistry.contract.WatchLogs(opts, "FeeSplitProposed")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PeripheryRegistryFeeSplitProposed)
				if err := _PeripheryRegistry.contract.UnpackLog(event, "FeeSplitProposed", log); err != nil {
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

// ParseFeeSplitProposed is a log parse operation binding the contract event 0x33f6ffd7ef6e2fbeec2756d83bf09809997101b62f86ef82fa0169570eee5cb5.
//
// Solidity: event FeeSplitProposed(uint256 superformFeeSplit, uint256 effectiveTime)
func (_PeripheryRegistry *PeripheryRegistryFilterer) ParseFeeSplitProposed(log types.Log) (*PeripheryRegistryFeeSplitProposed, error) {
	event := new(PeripheryRegistryFeeSplitProposed)
	if err := _PeripheryRegistry.contract.UnpackLog(event, "FeeSplitProposed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PeripheryRegistryFeeSplitUpdatedIterator is returned from FilterFeeSplitUpdated and is used to iterate over the raw logs and unpacked data for FeeSplitUpdated events raised by the PeripheryRegistry contract.
type PeripheryRegistryFeeSplitUpdatedIterator struct {
	Event *PeripheryRegistryFeeSplitUpdated // Event containing the contract specifics and raw log

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
func (it *PeripheryRegistryFeeSplitUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PeripheryRegistryFeeSplitUpdated)
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
		it.Event = new(PeripheryRegistryFeeSplitUpdated)
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
func (it *PeripheryRegistryFeeSplitUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PeripheryRegistryFeeSplitUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PeripheryRegistryFeeSplitUpdated represents a FeeSplitUpdated event raised by the PeripheryRegistry contract.
type PeripheryRegistryFeeSplitUpdated struct {
	SuperformFeeSplit *big.Int
	Raw               types.Log // Blockchain specific contextual infos
}

// FilterFeeSplitUpdated is a free log retrieval operation binding the contract event 0x23e50f4213503cbe5cbbcbd5abed363d018f6800f8027766632969ffef35b254.
//
// Solidity: event FeeSplitUpdated(uint256 superformFeeSplit)
func (_PeripheryRegistry *PeripheryRegistryFilterer) FilterFeeSplitUpdated(opts *bind.FilterOpts) (*PeripheryRegistryFeeSplitUpdatedIterator, error) {

	logs, sub, err := _PeripheryRegistry.contract.FilterLogs(opts, "FeeSplitUpdated")
	if err != nil {
		return nil, err
	}
	return &PeripheryRegistryFeeSplitUpdatedIterator{contract: _PeripheryRegistry.contract, event: "FeeSplitUpdated", logs: logs, sub: sub}, nil
}

// WatchFeeSplitUpdated is a free log subscription operation binding the contract event 0x23e50f4213503cbe5cbbcbd5abed363d018f6800f8027766632969ffef35b254.
//
// Solidity: event FeeSplitUpdated(uint256 superformFeeSplit)
func (_PeripheryRegistry *PeripheryRegistryFilterer) WatchFeeSplitUpdated(opts *bind.WatchOpts, sink chan<- *PeripheryRegistryFeeSplitUpdated) (event.Subscription, error) {

	logs, sub, err := _PeripheryRegistry.contract.WatchLogs(opts, "FeeSplitUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PeripheryRegistryFeeSplitUpdated)
				if err := _PeripheryRegistry.contract.UnpackLog(event, "FeeSplitUpdated", log); err != nil {
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

// ParseFeeSplitUpdated is a log parse operation binding the contract event 0x23e50f4213503cbe5cbbcbd5abed363d018f6800f8027766632969ffef35b254.
//
// Solidity: event FeeSplitUpdated(uint256 superformFeeSplit)
func (_PeripheryRegistry *PeripheryRegistryFilterer) ParseFeeSplitUpdated(log types.Log) (*PeripheryRegistryFeeSplitUpdated, error) {
	event := new(PeripheryRegistryFeeSplitUpdated)
	if err := _PeripheryRegistry.contract.UnpackLog(event, "FeeSplitUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PeripheryRegistryHookRegisteredIterator is returned from FilterHookRegistered and is used to iterate over the raw logs and unpacked data for HookRegistered events raised by the PeripheryRegistry contract.
type PeripheryRegistryHookRegisteredIterator struct {
	Event *PeripheryRegistryHookRegistered // Event containing the contract specifics and raw log

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
func (it *PeripheryRegistryHookRegisteredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PeripheryRegistryHookRegistered)
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
		it.Event = new(PeripheryRegistryHookRegistered)
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
func (it *PeripheryRegistryHookRegisteredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PeripheryRegistryHookRegisteredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PeripheryRegistryHookRegistered represents a HookRegistered event raised by the PeripheryRegistry contract.
type PeripheryRegistryHookRegistered struct {
	Hook common.Address
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterHookRegistered is a free log retrieval operation binding the contract event 0xc32bc16f2ad4b9008fd1cda71adb222d318bd824de7796c6970a76ca3fdbd604.
//
// Solidity: event HookRegistered(address indexed hook)
func (_PeripheryRegistry *PeripheryRegistryFilterer) FilterHookRegistered(opts *bind.FilterOpts, hook []common.Address) (*PeripheryRegistryHookRegisteredIterator, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}

	logs, sub, err := _PeripheryRegistry.contract.FilterLogs(opts, "HookRegistered", hookRule)
	if err != nil {
		return nil, err
	}
	return &PeripheryRegistryHookRegisteredIterator{contract: _PeripheryRegistry.contract, event: "HookRegistered", logs: logs, sub: sub}, nil
}

// WatchHookRegistered is a free log subscription operation binding the contract event 0xc32bc16f2ad4b9008fd1cda71adb222d318bd824de7796c6970a76ca3fdbd604.
//
// Solidity: event HookRegistered(address indexed hook)
func (_PeripheryRegistry *PeripheryRegistryFilterer) WatchHookRegistered(opts *bind.WatchOpts, sink chan<- *PeripheryRegistryHookRegistered, hook []common.Address) (event.Subscription, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}

	logs, sub, err := _PeripheryRegistry.contract.WatchLogs(opts, "HookRegistered", hookRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PeripheryRegistryHookRegistered)
				if err := _PeripheryRegistry.contract.UnpackLog(event, "HookRegistered", log); err != nil {
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

// ParseHookRegistered is a log parse operation binding the contract event 0xc32bc16f2ad4b9008fd1cda71adb222d318bd824de7796c6970a76ca3fdbd604.
//
// Solidity: event HookRegistered(address indexed hook)
func (_PeripheryRegistry *PeripheryRegistryFilterer) ParseHookRegistered(log types.Log) (*PeripheryRegistryHookRegistered, error) {
	event := new(PeripheryRegistryHookRegistered)
	if err := _PeripheryRegistry.contract.UnpackLog(event, "HookRegistered", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PeripheryRegistryHookUnregisteredIterator is returned from FilterHookUnregistered and is used to iterate over the raw logs and unpacked data for HookUnregistered events raised by the PeripheryRegistry contract.
type PeripheryRegistryHookUnregisteredIterator struct {
	Event *PeripheryRegistryHookUnregistered // Event containing the contract specifics and raw log

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
func (it *PeripheryRegistryHookUnregisteredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PeripheryRegistryHookUnregistered)
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
		it.Event = new(PeripheryRegistryHookUnregistered)
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
func (it *PeripheryRegistryHookUnregisteredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PeripheryRegistryHookUnregisteredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PeripheryRegistryHookUnregistered represents a HookUnregistered event raised by the PeripheryRegistry contract.
type PeripheryRegistryHookUnregistered struct {
	Hook common.Address
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterHookUnregistered is a free log retrieval operation binding the contract event 0xcab1186db73fd6ffc8a180fe72ddc46758a3d793140e0946340e92998cd0a8b3.
//
// Solidity: event HookUnregistered(address indexed hook)
func (_PeripheryRegistry *PeripheryRegistryFilterer) FilterHookUnregistered(opts *bind.FilterOpts, hook []common.Address) (*PeripheryRegistryHookUnregisteredIterator, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}

	logs, sub, err := _PeripheryRegistry.contract.FilterLogs(opts, "HookUnregistered", hookRule)
	if err != nil {
		return nil, err
	}
	return &PeripheryRegistryHookUnregisteredIterator{contract: _PeripheryRegistry.contract, event: "HookUnregistered", logs: logs, sub: sub}, nil
}

// WatchHookUnregistered is a free log subscription operation binding the contract event 0xcab1186db73fd6ffc8a180fe72ddc46758a3d793140e0946340e92998cd0a8b3.
//
// Solidity: event HookUnregistered(address indexed hook)
func (_PeripheryRegistry *PeripheryRegistryFilterer) WatchHookUnregistered(opts *bind.WatchOpts, sink chan<- *PeripheryRegistryHookUnregistered, hook []common.Address) (event.Subscription, error) {

	var hookRule []interface{}
	for _, hookItem := range hook {
		hookRule = append(hookRule, hookItem)
	}

	logs, sub, err := _PeripheryRegistry.contract.WatchLogs(opts, "HookUnregistered", hookRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PeripheryRegistryHookUnregistered)
				if err := _PeripheryRegistry.contract.UnpackLog(event, "HookUnregistered", log); err != nil {
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

// ParseHookUnregistered is a log parse operation binding the contract event 0xcab1186db73fd6ffc8a180fe72ddc46758a3d793140e0946340e92998cd0a8b3.
//
// Solidity: event HookUnregistered(address indexed hook)
func (_PeripheryRegistry *PeripheryRegistryFilterer) ParseHookUnregistered(log types.Log) (*PeripheryRegistryHookUnregistered, error) {
	event := new(PeripheryRegistryHookUnregistered)
	if err := _PeripheryRegistry.contract.UnpackLog(event, "HookUnregistered", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PeripheryRegistryOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the PeripheryRegistry contract.
type PeripheryRegistryOwnershipTransferStartedIterator struct {
	Event *PeripheryRegistryOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *PeripheryRegistryOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PeripheryRegistryOwnershipTransferStarted)
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
		it.Event = new(PeripheryRegistryOwnershipTransferStarted)
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
func (it *PeripheryRegistryOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PeripheryRegistryOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PeripheryRegistryOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the PeripheryRegistry contract.
type PeripheryRegistryOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_PeripheryRegistry *PeripheryRegistryFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*PeripheryRegistryOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _PeripheryRegistry.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &PeripheryRegistryOwnershipTransferStartedIterator{contract: _PeripheryRegistry.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_PeripheryRegistry *PeripheryRegistryFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *PeripheryRegistryOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _PeripheryRegistry.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PeripheryRegistryOwnershipTransferStarted)
				if err := _PeripheryRegistry.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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

// ParseOwnershipTransferStarted is a log parse operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_PeripheryRegistry *PeripheryRegistryFilterer) ParseOwnershipTransferStarted(log types.Log) (*PeripheryRegistryOwnershipTransferStarted, error) {
	event := new(PeripheryRegistryOwnershipTransferStarted)
	if err := _PeripheryRegistry.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PeripheryRegistryOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the PeripheryRegistry contract.
type PeripheryRegistryOwnershipTransferredIterator struct {
	Event *PeripheryRegistryOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *PeripheryRegistryOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PeripheryRegistryOwnershipTransferred)
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
		it.Event = new(PeripheryRegistryOwnershipTransferred)
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
func (it *PeripheryRegistryOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PeripheryRegistryOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PeripheryRegistryOwnershipTransferred represents a OwnershipTransferred event raised by the PeripheryRegistry contract.
type PeripheryRegistryOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_PeripheryRegistry *PeripheryRegistryFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*PeripheryRegistryOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _PeripheryRegistry.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &PeripheryRegistryOwnershipTransferredIterator{contract: _PeripheryRegistry.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_PeripheryRegistry *PeripheryRegistryFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *PeripheryRegistryOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _PeripheryRegistry.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PeripheryRegistryOwnershipTransferred)
				if err := _PeripheryRegistry.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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

// ParseOwnershipTransferred is a log parse operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_PeripheryRegistry *PeripheryRegistryFilterer) ParseOwnershipTransferred(log types.Log) (*PeripheryRegistryOwnershipTransferred, error) {
	event := new(PeripheryRegistryOwnershipTransferred)
	if err := _PeripheryRegistry.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PeripheryRegistryTreasuryUpdatedIterator is returned from FilterTreasuryUpdated and is used to iterate over the raw logs and unpacked data for TreasuryUpdated events raised by the PeripheryRegistry contract.
type PeripheryRegistryTreasuryUpdatedIterator struct {
	Event *PeripheryRegistryTreasuryUpdated // Event containing the contract specifics and raw log

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
func (it *PeripheryRegistryTreasuryUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PeripheryRegistryTreasuryUpdated)
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
		it.Event = new(PeripheryRegistryTreasuryUpdated)
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
func (it *PeripheryRegistryTreasuryUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PeripheryRegistryTreasuryUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PeripheryRegistryTreasuryUpdated represents a TreasuryUpdated event raised by the PeripheryRegistry contract.
type PeripheryRegistryTreasuryUpdated struct {
	Treasury common.Address
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterTreasuryUpdated is a free log retrieval operation binding the contract event 0x7dae230f18360d76a040c81f050aa14eb9d6dc7901b20fc5d855e2a20fe814d1.
//
// Solidity: event TreasuryUpdated(address indexed treasury)
func (_PeripheryRegistry *PeripheryRegistryFilterer) FilterTreasuryUpdated(opts *bind.FilterOpts, treasury []common.Address) (*PeripheryRegistryTreasuryUpdatedIterator, error) {

	var treasuryRule []interface{}
	for _, treasuryItem := range treasury {
		treasuryRule = append(treasuryRule, treasuryItem)
	}

	logs, sub, err := _PeripheryRegistry.contract.FilterLogs(opts, "TreasuryUpdated", treasuryRule)
	if err != nil {
		return nil, err
	}
	return &PeripheryRegistryTreasuryUpdatedIterator{contract: _PeripheryRegistry.contract, event: "TreasuryUpdated", logs: logs, sub: sub}, nil
}

// WatchTreasuryUpdated is a free log subscription operation binding the contract event 0x7dae230f18360d76a040c81f050aa14eb9d6dc7901b20fc5d855e2a20fe814d1.
//
// Solidity: event TreasuryUpdated(address indexed treasury)
func (_PeripheryRegistry *PeripheryRegistryFilterer) WatchTreasuryUpdated(opts *bind.WatchOpts, sink chan<- *PeripheryRegistryTreasuryUpdated, treasury []common.Address) (event.Subscription, error) {

	var treasuryRule []interface{}
	for _, treasuryItem := range treasury {
		treasuryRule = append(treasuryRule, treasuryItem)
	}

	logs, sub, err := _PeripheryRegistry.contract.WatchLogs(opts, "TreasuryUpdated", treasuryRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PeripheryRegistryTreasuryUpdated)
				if err := _PeripheryRegistry.contract.UnpackLog(event, "TreasuryUpdated", log); err != nil {
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

// ParseTreasuryUpdated is a log parse operation binding the contract event 0x7dae230f18360d76a040c81f050aa14eb9d6dc7901b20fc5d855e2a20fe814d1.
//
// Solidity: event TreasuryUpdated(address indexed treasury)
func (_PeripheryRegistry *PeripheryRegistryFilterer) ParseTreasuryUpdated(log types.Log) (*PeripheryRegistryTreasuryUpdated, error) {
	event := new(PeripheryRegistryTreasuryUpdated)
	if err := _PeripheryRegistry.contract.UnpackLog(event, "TreasuryUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
