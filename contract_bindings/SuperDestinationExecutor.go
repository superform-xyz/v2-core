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

// SuperDestinationExecutorMetaData contains all meta data concerning the SuperDestinationExecutor contract.
var SuperDestinationExecutorMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"ledgerConfiguration_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"superDestinationValidator_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"nexusFactory_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"execute\",\"inputs\":[{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isInitialized\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isMerkleRootUsed\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"merkleRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isModuleType\",\"inputs\":[{\"name\":\"typeID\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"ledgerConfiguration\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperLedgerConfiguration\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"name\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"nexusFactory\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractINexusFactory\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"onInstall\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"onUninstall\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"processBridgedExecution\",\"inputs\":[{\"name\":\"tokenSent\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"intentAmount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"initData\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"executorCalldata\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"userSignatureData\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"superDestinationValidator\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"usedMerkleRoots\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"merkleRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"used\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"version\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"pure\"},{\"type\":\"event\",\"name\":\"AccountCreated\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"salt\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperDestinationExecutorExecuted\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperDestinationExecutorFailed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"reason\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperDestinationExecutorFailedLowLevel\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"lowLevelData\",\"type\":\"bytes\",\"indexed\":false,\"internalType\":\"bytes\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperDestinationExecutorReceivedButNoHooks\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperDestinationExecutorReceivedButNotEnoughBalance\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperPositionLocked\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"spToken\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCOUNT_NOT_CREATED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_ACCOUNT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ALREADY_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FEE_NOT_TRANSFERRED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_BALANCE_FOR_FEE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_ACCOUNT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_FEE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_SIGNATURE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MANAGER_NOT_SET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MERKLE_ROOT_ALREADY_USED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ModuleAlreadyInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"NOT_AUTHORIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_HOOKS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"ReentrancyGuardReentrantCall\",\"inputs\":[]}]",
}

// SuperDestinationExecutorABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperDestinationExecutorMetaData.ABI instead.
var SuperDestinationExecutorABI = SuperDestinationExecutorMetaData.ABI

// SuperDestinationExecutor is an auto generated Go binding around an Ethereum contract.
type SuperDestinationExecutor struct {
	SuperDestinationExecutorCaller     // Read-only binding to the contract
	SuperDestinationExecutorTransactor // Write-only binding to the contract
	SuperDestinationExecutorFilterer   // Log filterer for contract events
}

// SuperDestinationExecutorCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperDestinationExecutorCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperDestinationExecutorTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperDestinationExecutorTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperDestinationExecutorFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperDestinationExecutorFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperDestinationExecutorSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperDestinationExecutorSession struct {
	Contract     *SuperDestinationExecutor // Generic contract binding to set the session for
	CallOpts     bind.CallOpts             // Call options to use throughout this session
	TransactOpts bind.TransactOpts         // Transaction auth options to use throughout this session
}

// SuperDestinationExecutorCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperDestinationExecutorCallerSession struct {
	Contract *SuperDestinationExecutorCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                   // Call options to use throughout this session
}

// SuperDestinationExecutorTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperDestinationExecutorTransactorSession struct {
	Contract     *SuperDestinationExecutorTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                   // Transaction auth options to use throughout this session
}

// SuperDestinationExecutorRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperDestinationExecutorRaw struct {
	Contract *SuperDestinationExecutor // Generic contract binding to access the raw methods on
}

// SuperDestinationExecutorCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperDestinationExecutorCallerRaw struct {
	Contract *SuperDestinationExecutorCaller // Generic read-only contract binding to access the raw methods on
}

// SuperDestinationExecutorTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperDestinationExecutorTransactorRaw struct {
	Contract *SuperDestinationExecutorTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperDestinationExecutor creates a new instance of SuperDestinationExecutor, bound to a specific deployed contract.
func NewSuperDestinationExecutor(address common.Address, backend bind.ContractBackend) (*SuperDestinationExecutor, error) {
	contract, err := bindSuperDestinationExecutor(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationExecutor{SuperDestinationExecutorCaller: SuperDestinationExecutorCaller{contract: contract}, SuperDestinationExecutorTransactor: SuperDestinationExecutorTransactor{contract: contract}, SuperDestinationExecutorFilterer: SuperDestinationExecutorFilterer{contract: contract}}, nil
}

// NewSuperDestinationExecutorCaller creates a new read-only instance of SuperDestinationExecutor, bound to a specific deployed contract.
func NewSuperDestinationExecutorCaller(address common.Address, caller bind.ContractCaller) (*SuperDestinationExecutorCaller, error) {
	contract, err := bindSuperDestinationExecutor(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationExecutorCaller{contract: contract}, nil
}

// NewSuperDestinationExecutorTransactor creates a new write-only instance of SuperDestinationExecutor, bound to a specific deployed contract.
func NewSuperDestinationExecutorTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperDestinationExecutorTransactor, error) {
	contract, err := bindSuperDestinationExecutor(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationExecutorTransactor{contract: contract}, nil
}

// NewSuperDestinationExecutorFilterer creates a new log filterer instance of SuperDestinationExecutor, bound to a specific deployed contract.
func NewSuperDestinationExecutorFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperDestinationExecutorFilterer, error) {
	contract, err := bindSuperDestinationExecutor(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationExecutorFilterer{contract: contract}, nil
}

// bindSuperDestinationExecutor binds a generic wrapper to an already deployed contract.
func bindSuperDestinationExecutor(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperDestinationExecutorMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperDestinationExecutor *SuperDestinationExecutorRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperDestinationExecutor.Contract.SuperDestinationExecutorCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperDestinationExecutor *SuperDestinationExecutorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperDestinationExecutor.Contract.SuperDestinationExecutorTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperDestinationExecutor *SuperDestinationExecutorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperDestinationExecutor.Contract.SuperDestinationExecutorTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperDestinationExecutor *SuperDestinationExecutorCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperDestinationExecutor.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperDestinationExecutor *SuperDestinationExecutorTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperDestinationExecutor.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperDestinationExecutor *SuperDestinationExecutorTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperDestinationExecutor.Contract.contract.Transact(opts, method, params...)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperDestinationExecutor *SuperDestinationExecutorCaller) IsInitialized(opts *bind.CallOpts, account common.Address) (bool, error) {
	var out []interface{}
	err := _SuperDestinationExecutor.contract.Call(opts, &out, "isInitialized", account)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperDestinationExecutor *SuperDestinationExecutorSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperDestinationExecutor.Contract.IsInitialized(&_SuperDestinationExecutor.CallOpts, account)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperDestinationExecutor *SuperDestinationExecutorCallerSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperDestinationExecutor.Contract.IsInitialized(&_SuperDestinationExecutor.CallOpts, account)
}

// IsMerkleRootUsed is a free data retrieval call binding the contract method 0x244cd767.
//
// Solidity: function isMerkleRootUsed(address user, bytes32 merkleRoot) view returns(bool)
func (_SuperDestinationExecutor *SuperDestinationExecutorCaller) IsMerkleRootUsed(opts *bind.CallOpts, user common.Address, merkleRoot [32]byte) (bool, error) {
	var out []interface{}
	err := _SuperDestinationExecutor.contract.Call(opts, &out, "isMerkleRootUsed", user, merkleRoot)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsMerkleRootUsed is a free data retrieval call binding the contract method 0x244cd767.
//
// Solidity: function isMerkleRootUsed(address user, bytes32 merkleRoot) view returns(bool)
func (_SuperDestinationExecutor *SuperDestinationExecutorSession) IsMerkleRootUsed(user common.Address, merkleRoot [32]byte) (bool, error) {
	return _SuperDestinationExecutor.Contract.IsMerkleRootUsed(&_SuperDestinationExecutor.CallOpts, user, merkleRoot)
}

// IsMerkleRootUsed is a free data retrieval call binding the contract method 0x244cd767.
//
// Solidity: function isMerkleRootUsed(address user, bytes32 merkleRoot) view returns(bool)
func (_SuperDestinationExecutor *SuperDestinationExecutorCallerSession) IsMerkleRootUsed(user common.Address, merkleRoot [32]byte) (bool, error) {
	return _SuperDestinationExecutor.Contract.IsMerkleRootUsed(&_SuperDestinationExecutor.CallOpts, user, merkleRoot)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeID) pure returns(bool)
func (_SuperDestinationExecutor *SuperDestinationExecutorCaller) IsModuleType(opts *bind.CallOpts, typeID *big.Int) (bool, error) {
	var out []interface{}
	err := _SuperDestinationExecutor.contract.Call(opts, &out, "isModuleType", typeID)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeID) pure returns(bool)
func (_SuperDestinationExecutor *SuperDestinationExecutorSession) IsModuleType(typeID *big.Int) (bool, error) {
	return _SuperDestinationExecutor.Contract.IsModuleType(&_SuperDestinationExecutor.CallOpts, typeID)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeID) pure returns(bool)
func (_SuperDestinationExecutor *SuperDestinationExecutorCallerSession) IsModuleType(typeID *big.Int) (bool, error) {
	return _SuperDestinationExecutor.Contract.IsModuleType(&_SuperDestinationExecutor.CallOpts, typeID)
}

// LedgerConfiguration is a free data retrieval call binding the contract method 0x6740419b.
//
// Solidity: function ledgerConfiguration() view returns(address)
func (_SuperDestinationExecutor *SuperDestinationExecutorCaller) LedgerConfiguration(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperDestinationExecutor.contract.Call(opts, &out, "ledgerConfiguration")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// LedgerConfiguration is a free data retrieval call binding the contract method 0x6740419b.
//
// Solidity: function ledgerConfiguration() view returns(address)
func (_SuperDestinationExecutor *SuperDestinationExecutorSession) LedgerConfiguration() (common.Address, error) {
	return _SuperDestinationExecutor.Contract.LedgerConfiguration(&_SuperDestinationExecutor.CallOpts)
}

// LedgerConfiguration is a free data retrieval call binding the contract method 0x6740419b.
//
// Solidity: function ledgerConfiguration() view returns(address)
func (_SuperDestinationExecutor *SuperDestinationExecutorCallerSession) LedgerConfiguration() (common.Address, error) {
	return _SuperDestinationExecutor.Contract.LedgerConfiguration(&_SuperDestinationExecutor.CallOpts)
}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() pure returns(string)
func (_SuperDestinationExecutor *SuperDestinationExecutorCaller) Name(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperDestinationExecutor.contract.Call(opts, &out, "name")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() pure returns(string)
func (_SuperDestinationExecutor *SuperDestinationExecutorSession) Name() (string, error) {
	return _SuperDestinationExecutor.Contract.Name(&_SuperDestinationExecutor.CallOpts)
}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() pure returns(string)
func (_SuperDestinationExecutor *SuperDestinationExecutorCallerSession) Name() (string, error) {
	return _SuperDestinationExecutor.Contract.Name(&_SuperDestinationExecutor.CallOpts)
}

// NexusFactory is a free data retrieval call binding the contract method 0x73d070af.
//
// Solidity: function nexusFactory() view returns(address)
func (_SuperDestinationExecutor *SuperDestinationExecutorCaller) NexusFactory(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperDestinationExecutor.contract.Call(opts, &out, "nexusFactory")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// NexusFactory is a free data retrieval call binding the contract method 0x73d070af.
//
// Solidity: function nexusFactory() view returns(address)
func (_SuperDestinationExecutor *SuperDestinationExecutorSession) NexusFactory() (common.Address, error) {
	return _SuperDestinationExecutor.Contract.NexusFactory(&_SuperDestinationExecutor.CallOpts)
}

// NexusFactory is a free data retrieval call binding the contract method 0x73d070af.
//
// Solidity: function nexusFactory() view returns(address)
func (_SuperDestinationExecutor *SuperDestinationExecutorCallerSession) NexusFactory() (common.Address, error) {
	return _SuperDestinationExecutor.Contract.NexusFactory(&_SuperDestinationExecutor.CallOpts)
}

// SuperDestinationValidator is a free data retrieval call binding the contract method 0x4ddc738a.
//
// Solidity: function superDestinationValidator() view returns(address)
func (_SuperDestinationExecutor *SuperDestinationExecutorCaller) SuperDestinationValidator(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperDestinationExecutor.contract.Call(opts, &out, "superDestinationValidator")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SuperDestinationValidator is a free data retrieval call binding the contract method 0x4ddc738a.
//
// Solidity: function superDestinationValidator() view returns(address)
func (_SuperDestinationExecutor *SuperDestinationExecutorSession) SuperDestinationValidator() (common.Address, error) {
	return _SuperDestinationExecutor.Contract.SuperDestinationValidator(&_SuperDestinationExecutor.CallOpts)
}

// SuperDestinationValidator is a free data retrieval call binding the contract method 0x4ddc738a.
//
// Solidity: function superDestinationValidator() view returns(address)
func (_SuperDestinationExecutor *SuperDestinationExecutorCallerSession) SuperDestinationValidator() (common.Address, error) {
	return _SuperDestinationExecutor.Contract.SuperDestinationValidator(&_SuperDestinationExecutor.CallOpts)
}

// UsedMerkleRoots is a free data retrieval call binding the contract method 0xa5b6f208.
//
// Solidity: function usedMerkleRoots(address user, bytes32 merkleRoot) view returns(bool used)
func (_SuperDestinationExecutor *SuperDestinationExecutorCaller) UsedMerkleRoots(opts *bind.CallOpts, user common.Address, merkleRoot [32]byte) (bool, error) {
	var out []interface{}
	err := _SuperDestinationExecutor.contract.Call(opts, &out, "usedMerkleRoots", user, merkleRoot)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// UsedMerkleRoots is a free data retrieval call binding the contract method 0xa5b6f208.
//
// Solidity: function usedMerkleRoots(address user, bytes32 merkleRoot) view returns(bool used)
func (_SuperDestinationExecutor *SuperDestinationExecutorSession) UsedMerkleRoots(user common.Address, merkleRoot [32]byte) (bool, error) {
	return _SuperDestinationExecutor.Contract.UsedMerkleRoots(&_SuperDestinationExecutor.CallOpts, user, merkleRoot)
}

// UsedMerkleRoots is a free data retrieval call binding the contract method 0xa5b6f208.
//
// Solidity: function usedMerkleRoots(address user, bytes32 merkleRoot) view returns(bool used)
func (_SuperDestinationExecutor *SuperDestinationExecutorCallerSession) UsedMerkleRoots(user common.Address, merkleRoot [32]byte) (bool, error) {
	return _SuperDestinationExecutor.Contract.UsedMerkleRoots(&_SuperDestinationExecutor.CallOpts, user, merkleRoot)
}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() pure returns(string)
func (_SuperDestinationExecutor *SuperDestinationExecutorCaller) Version(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperDestinationExecutor.contract.Call(opts, &out, "version")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() pure returns(string)
func (_SuperDestinationExecutor *SuperDestinationExecutorSession) Version() (string, error) {
	return _SuperDestinationExecutor.Contract.Version(&_SuperDestinationExecutor.CallOpts)
}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() pure returns(string)
func (_SuperDestinationExecutor *SuperDestinationExecutorCallerSession) Version() (string, error) {
	return _SuperDestinationExecutor.Contract.Version(&_SuperDestinationExecutor.CallOpts)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_SuperDestinationExecutor *SuperDestinationExecutorTransactor) Execute(opts *bind.TransactOpts, data []byte) (*types.Transaction, error) {
	return _SuperDestinationExecutor.contract.Transact(opts, "execute", data)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_SuperDestinationExecutor *SuperDestinationExecutorSession) Execute(data []byte) (*types.Transaction, error) {
	return _SuperDestinationExecutor.Contract.Execute(&_SuperDestinationExecutor.TransactOpts, data)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_SuperDestinationExecutor *SuperDestinationExecutorTransactorSession) Execute(data []byte) (*types.Transaction, error) {
	return _SuperDestinationExecutor.Contract.Execute(&_SuperDestinationExecutor.TransactOpts, data)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_SuperDestinationExecutor *SuperDestinationExecutorTransactor) OnInstall(opts *bind.TransactOpts, arg0 []byte) (*types.Transaction, error) {
	return _SuperDestinationExecutor.contract.Transact(opts, "onInstall", arg0)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_SuperDestinationExecutor *SuperDestinationExecutorSession) OnInstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperDestinationExecutor.Contract.OnInstall(&_SuperDestinationExecutor.TransactOpts, arg0)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_SuperDestinationExecutor *SuperDestinationExecutorTransactorSession) OnInstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperDestinationExecutor.Contract.OnInstall(&_SuperDestinationExecutor.TransactOpts, arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperDestinationExecutor *SuperDestinationExecutorTransactor) OnUninstall(opts *bind.TransactOpts, arg0 []byte) (*types.Transaction, error) {
	return _SuperDestinationExecutor.contract.Transact(opts, "onUninstall", arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperDestinationExecutor *SuperDestinationExecutorSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperDestinationExecutor.Contract.OnUninstall(&_SuperDestinationExecutor.TransactOpts, arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperDestinationExecutor *SuperDestinationExecutorTransactorSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperDestinationExecutor.Contract.OnUninstall(&_SuperDestinationExecutor.TransactOpts, arg0)
}

// ProcessBridgedExecution is a paid mutator transaction binding the contract method 0x5cc3fc0e.
//
// Solidity: function processBridgedExecution(address tokenSent, address account, uint256 intentAmount, bytes initData, bytes executorCalldata, bytes userSignatureData) returns()
func (_SuperDestinationExecutor *SuperDestinationExecutorTransactor) ProcessBridgedExecution(opts *bind.TransactOpts, tokenSent common.Address, account common.Address, intentAmount *big.Int, initData []byte, executorCalldata []byte, userSignatureData []byte) (*types.Transaction, error) {
	return _SuperDestinationExecutor.contract.Transact(opts, "processBridgedExecution", tokenSent, account, intentAmount, initData, executorCalldata, userSignatureData)
}

// ProcessBridgedExecution is a paid mutator transaction binding the contract method 0x5cc3fc0e.
//
// Solidity: function processBridgedExecution(address tokenSent, address account, uint256 intentAmount, bytes initData, bytes executorCalldata, bytes userSignatureData) returns()
func (_SuperDestinationExecutor *SuperDestinationExecutorSession) ProcessBridgedExecution(tokenSent common.Address, account common.Address, intentAmount *big.Int, initData []byte, executorCalldata []byte, userSignatureData []byte) (*types.Transaction, error) {
	return _SuperDestinationExecutor.Contract.ProcessBridgedExecution(&_SuperDestinationExecutor.TransactOpts, tokenSent, account, intentAmount, initData, executorCalldata, userSignatureData)
}

// ProcessBridgedExecution is a paid mutator transaction binding the contract method 0x5cc3fc0e.
//
// Solidity: function processBridgedExecution(address tokenSent, address account, uint256 intentAmount, bytes initData, bytes executorCalldata, bytes userSignatureData) returns()
func (_SuperDestinationExecutor *SuperDestinationExecutorTransactorSession) ProcessBridgedExecution(tokenSent common.Address, account common.Address, intentAmount *big.Int, initData []byte, executorCalldata []byte, userSignatureData []byte) (*types.Transaction, error) {
	return _SuperDestinationExecutor.Contract.ProcessBridgedExecution(&_SuperDestinationExecutor.TransactOpts, tokenSent, account, intentAmount, initData, executorCalldata, userSignatureData)
}

// SuperDestinationExecutorAccountCreatedIterator is returned from FilterAccountCreated and is used to iterate over the raw logs and unpacked data for AccountCreated events raised by the SuperDestinationExecutor contract.
type SuperDestinationExecutorAccountCreatedIterator struct {
	Event *SuperDestinationExecutorAccountCreated // Event containing the contract specifics and raw log

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
func (it *SuperDestinationExecutorAccountCreatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperDestinationExecutorAccountCreated)
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
		it.Event = new(SuperDestinationExecutorAccountCreated)
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
func (it *SuperDestinationExecutorAccountCreatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperDestinationExecutorAccountCreatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperDestinationExecutorAccountCreated represents a AccountCreated event raised by the SuperDestinationExecutor contract.
type SuperDestinationExecutorAccountCreated struct {
	Account common.Address
	Salt    [32]byte
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAccountCreated is a free log retrieval operation binding the contract event 0x8fe66a5d954d6d3e0306797e31e226812a9916895165c96c367ef52807631951.
//
// Solidity: event AccountCreated(address indexed account, bytes32 salt)
func (_SuperDestinationExecutor *SuperDestinationExecutorFilterer) FilterAccountCreated(opts *bind.FilterOpts, account []common.Address) (*SuperDestinationExecutorAccountCreatedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperDestinationExecutor.contract.FilterLogs(opts, "AccountCreated", accountRule)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationExecutorAccountCreatedIterator{contract: _SuperDestinationExecutor.contract, event: "AccountCreated", logs: logs, sub: sub}, nil
}

// WatchAccountCreated is a free log subscription operation binding the contract event 0x8fe66a5d954d6d3e0306797e31e226812a9916895165c96c367ef52807631951.
//
// Solidity: event AccountCreated(address indexed account, bytes32 salt)
func (_SuperDestinationExecutor *SuperDestinationExecutorFilterer) WatchAccountCreated(opts *bind.WatchOpts, sink chan<- *SuperDestinationExecutorAccountCreated, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperDestinationExecutor.contract.WatchLogs(opts, "AccountCreated", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperDestinationExecutorAccountCreated)
				if err := _SuperDestinationExecutor.contract.UnpackLog(event, "AccountCreated", log); err != nil {
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

// ParseAccountCreated is a log parse operation binding the contract event 0x8fe66a5d954d6d3e0306797e31e226812a9916895165c96c367ef52807631951.
//
// Solidity: event AccountCreated(address indexed account, bytes32 salt)
func (_SuperDestinationExecutor *SuperDestinationExecutorFilterer) ParseAccountCreated(log types.Log) (*SuperDestinationExecutorAccountCreated, error) {
	event := new(SuperDestinationExecutorAccountCreated)
	if err := _SuperDestinationExecutor.contract.UnpackLog(event, "AccountCreated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperDestinationExecutorSuperDestinationExecutorExecutedIterator is returned from FilterSuperDestinationExecutorExecuted and is used to iterate over the raw logs and unpacked data for SuperDestinationExecutorExecuted events raised by the SuperDestinationExecutor contract.
type SuperDestinationExecutorSuperDestinationExecutorExecutedIterator struct {
	Event *SuperDestinationExecutorSuperDestinationExecutorExecuted // Event containing the contract specifics and raw log

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
func (it *SuperDestinationExecutorSuperDestinationExecutorExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperDestinationExecutorSuperDestinationExecutorExecuted)
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
		it.Event = new(SuperDestinationExecutorSuperDestinationExecutorExecuted)
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
func (it *SuperDestinationExecutorSuperDestinationExecutorExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperDestinationExecutorSuperDestinationExecutorExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperDestinationExecutorSuperDestinationExecutorExecuted represents a SuperDestinationExecutorExecuted event raised by the SuperDestinationExecutor contract.
type SuperDestinationExecutorSuperDestinationExecutorExecuted struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterSuperDestinationExecutorExecuted is a free log retrieval operation binding the contract event 0x98f6e69f6c380877e68c669d19d23a062e9e5a9c18103278c08537aae6fd825e.
//
// Solidity: event SuperDestinationExecutorExecuted(address indexed account)
func (_SuperDestinationExecutor *SuperDestinationExecutorFilterer) FilterSuperDestinationExecutorExecuted(opts *bind.FilterOpts, account []common.Address) (*SuperDestinationExecutorSuperDestinationExecutorExecutedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperDestinationExecutor.contract.FilterLogs(opts, "SuperDestinationExecutorExecuted", accountRule)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationExecutorSuperDestinationExecutorExecutedIterator{contract: _SuperDestinationExecutor.contract, event: "SuperDestinationExecutorExecuted", logs: logs, sub: sub}, nil
}

// WatchSuperDestinationExecutorExecuted is a free log subscription operation binding the contract event 0x98f6e69f6c380877e68c669d19d23a062e9e5a9c18103278c08537aae6fd825e.
//
// Solidity: event SuperDestinationExecutorExecuted(address indexed account)
func (_SuperDestinationExecutor *SuperDestinationExecutorFilterer) WatchSuperDestinationExecutorExecuted(opts *bind.WatchOpts, sink chan<- *SuperDestinationExecutorSuperDestinationExecutorExecuted, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperDestinationExecutor.contract.WatchLogs(opts, "SuperDestinationExecutorExecuted", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperDestinationExecutorSuperDestinationExecutorExecuted)
				if err := _SuperDestinationExecutor.contract.UnpackLog(event, "SuperDestinationExecutorExecuted", log); err != nil {
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

// ParseSuperDestinationExecutorExecuted is a log parse operation binding the contract event 0x98f6e69f6c380877e68c669d19d23a062e9e5a9c18103278c08537aae6fd825e.
//
// Solidity: event SuperDestinationExecutorExecuted(address indexed account)
func (_SuperDestinationExecutor *SuperDestinationExecutorFilterer) ParseSuperDestinationExecutorExecuted(log types.Log) (*SuperDestinationExecutorSuperDestinationExecutorExecuted, error) {
	event := new(SuperDestinationExecutorSuperDestinationExecutorExecuted)
	if err := _SuperDestinationExecutor.contract.UnpackLog(event, "SuperDestinationExecutorExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperDestinationExecutorSuperDestinationExecutorFailedIterator is returned from FilterSuperDestinationExecutorFailed and is used to iterate over the raw logs and unpacked data for SuperDestinationExecutorFailed events raised by the SuperDestinationExecutor contract.
type SuperDestinationExecutorSuperDestinationExecutorFailedIterator struct {
	Event *SuperDestinationExecutorSuperDestinationExecutorFailed // Event containing the contract specifics and raw log

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
func (it *SuperDestinationExecutorSuperDestinationExecutorFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperDestinationExecutorSuperDestinationExecutorFailed)
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
		it.Event = new(SuperDestinationExecutorSuperDestinationExecutorFailed)
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
func (it *SuperDestinationExecutorSuperDestinationExecutorFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperDestinationExecutorSuperDestinationExecutorFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperDestinationExecutorSuperDestinationExecutorFailed represents a SuperDestinationExecutorFailed event raised by the SuperDestinationExecutor contract.
type SuperDestinationExecutorSuperDestinationExecutorFailed struct {
	Account common.Address
	Reason  string
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterSuperDestinationExecutorFailed is a free log retrieval operation binding the contract event 0xc743761b057969e0f19b0fd09905de355f91c90cb064de9c7fce1ae6c9bad1e0.
//
// Solidity: event SuperDestinationExecutorFailed(address indexed account, string reason)
func (_SuperDestinationExecutor *SuperDestinationExecutorFilterer) FilterSuperDestinationExecutorFailed(opts *bind.FilterOpts, account []common.Address) (*SuperDestinationExecutorSuperDestinationExecutorFailedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperDestinationExecutor.contract.FilterLogs(opts, "SuperDestinationExecutorFailed", accountRule)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationExecutorSuperDestinationExecutorFailedIterator{contract: _SuperDestinationExecutor.contract, event: "SuperDestinationExecutorFailed", logs: logs, sub: sub}, nil
}

// WatchSuperDestinationExecutorFailed is a free log subscription operation binding the contract event 0xc743761b057969e0f19b0fd09905de355f91c90cb064de9c7fce1ae6c9bad1e0.
//
// Solidity: event SuperDestinationExecutorFailed(address indexed account, string reason)
func (_SuperDestinationExecutor *SuperDestinationExecutorFilterer) WatchSuperDestinationExecutorFailed(opts *bind.WatchOpts, sink chan<- *SuperDestinationExecutorSuperDestinationExecutorFailed, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperDestinationExecutor.contract.WatchLogs(opts, "SuperDestinationExecutorFailed", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperDestinationExecutorSuperDestinationExecutorFailed)
				if err := _SuperDestinationExecutor.contract.UnpackLog(event, "SuperDestinationExecutorFailed", log); err != nil {
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

// ParseSuperDestinationExecutorFailed is a log parse operation binding the contract event 0xc743761b057969e0f19b0fd09905de355f91c90cb064de9c7fce1ae6c9bad1e0.
//
// Solidity: event SuperDestinationExecutorFailed(address indexed account, string reason)
func (_SuperDestinationExecutor *SuperDestinationExecutorFilterer) ParseSuperDestinationExecutorFailed(log types.Log) (*SuperDestinationExecutorSuperDestinationExecutorFailed, error) {
	event := new(SuperDestinationExecutorSuperDestinationExecutorFailed)
	if err := _SuperDestinationExecutor.contract.UnpackLog(event, "SuperDestinationExecutorFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperDestinationExecutorSuperDestinationExecutorFailedLowLevelIterator is returned from FilterSuperDestinationExecutorFailedLowLevel and is used to iterate over the raw logs and unpacked data for SuperDestinationExecutorFailedLowLevel events raised by the SuperDestinationExecutor contract.
type SuperDestinationExecutorSuperDestinationExecutorFailedLowLevelIterator struct {
	Event *SuperDestinationExecutorSuperDestinationExecutorFailedLowLevel // Event containing the contract specifics and raw log

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
func (it *SuperDestinationExecutorSuperDestinationExecutorFailedLowLevelIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperDestinationExecutorSuperDestinationExecutorFailedLowLevel)
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
		it.Event = new(SuperDestinationExecutorSuperDestinationExecutorFailedLowLevel)
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
func (it *SuperDestinationExecutorSuperDestinationExecutorFailedLowLevelIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperDestinationExecutorSuperDestinationExecutorFailedLowLevelIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperDestinationExecutorSuperDestinationExecutorFailedLowLevel represents a SuperDestinationExecutorFailedLowLevel event raised by the SuperDestinationExecutor contract.
type SuperDestinationExecutorSuperDestinationExecutorFailedLowLevel struct {
	Account      common.Address
	LowLevelData []byte
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterSuperDestinationExecutorFailedLowLevel is a free log retrieval operation binding the contract event 0x3ff63825b56f7ba8ea5c2124521d193e47f139521577e08ef7848d20ec9027a5.
//
// Solidity: event SuperDestinationExecutorFailedLowLevel(address indexed account, bytes lowLevelData)
func (_SuperDestinationExecutor *SuperDestinationExecutorFilterer) FilterSuperDestinationExecutorFailedLowLevel(opts *bind.FilterOpts, account []common.Address) (*SuperDestinationExecutorSuperDestinationExecutorFailedLowLevelIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperDestinationExecutor.contract.FilterLogs(opts, "SuperDestinationExecutorFailedLowLevel", accountRule)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationExecutorSuperDestinationExecutorFailedLowLevelIterator{contract: _SuperDestinationExecutor.contract, event: "SuperDestinationExecutorFailedLowLevel", logs: logs, sub: sub}, nil
}

// WatchSuperDestinationExecutorFailedLowLevel is a free log subscription operation binding the contract event 0x3ff63825b56f7ba8ea5c2124521d193e47f139521577e08ef7848d20ec9027a5.
//
// Solidity: event SuperDestinationExecutorFailedLowLevel(address indexed account, bytes lowLevelData)
func (_SuperDestinationExecutor *SuperDestinationExecutorFilterer) WatchSuperDestinationExecutorFailedLowLevel(opts *bind.WatchOpts, sink chan<- *SuperDestinationExecutorSuperDestinationExecutorFailedLowLevel, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperDestinationExecutor.contract.WatchLogs(opts, "SuperDestinationExecutorFailedLowLevel", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperDestinationExecutorSuperDestinationExecutorFailedLowLevel)
				if err := _SuperDestinationExecutor.contract.UnpackLog(event, "SuperDestinationExecutorFailedLowLevel", log); err != nil {
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

// ParseSuperDestinationExecutorFailedLowLevel is a log parse operation binding the contract event 0x3ff63825b56f7ba8ea5c2124521d193e47f139521577e08ef7848d20ec9027a5.
//
// Solidity: event SuperDestinationExecutorFailedLowLevel(address indexed account, bytes lowLevelData)
func (_SuperDestinationExecutor *SuperDestinationExecutorFilterer) ParseSuperDestinationExecutorFailedLowLevel(log types.Log) (*SuperDestinationExecutorSuperDestinationExecutorFailedLowLevel, error) {
	event := new(SuperDestinationExecutorSuperDestinationExecutorFailedLowLevel)
	if err := _SuperDestinationExecutor.contract.UnpackLog(event, "SuperDestinationExecutorFailedLowLevel", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperDestinationExecutorSuperDestinationExecutorReceivedButNoHooksIterator is returned from FilterSuperDestinationExecutorReceivedButNoHooks and is used to iterate over the raw logs and unpacked data for SuperDestinationExecutorReceivedButNoHooks events raised by the SuperDestinationExecutor contract.
type SuperDestinationExecutorSuperDestinationExecutorReceivedButNoHooksIterator struct {
	Event *SuperDestinationExecutorSuperDestinationExecutorReceivedButNoHooks // Event containing the contract specifics and raw log

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
func (it *SuperDestinationExecutorSuperDestinationExecutorReceivedButNoHooksIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperDestinationExecutorSuperDestinationExecutorReceivedButNoHooks)
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
		it.Event = new(SuperDestinationExecutorSuperDestinationExecutorReceivedButNoHooks)
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
func (it *SuperDestinationExecutorSuperDestinationExecutorReceivedButNoHooksIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperDestinationExecutorSuperDestinationExecutorReceivedButNoHooksIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperDestinationExecutorSuperDestinationExecutorReceivedButNoHooks represents a SuperDestinationExecutorReceivedButNoHooks event raised by the SuperDestinationExecutor contract.
type SuperDestinationExecutorSuperDestinationExecutorReceivedButNoHooks struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterSuperDestinationExecutorReceivedButNoHooks is a free log retrieval operation binding the contract event 0xb159537e384a9a796d3957f8a925c701e1a32cb359781d4b26ac895b02125f78.
//
// Solidity: event SuperDestinationExecutorReceivedButNoHooks(address indexed account)
func (_SuperDestinationExecutor *SuperDestinationExecutorFilterer) FilterSuperDestinationExecutorReceivedButNoHooks(opts *bind.FilterOpts, account []common.Address) (*SuperDestinationExecutorSuperDestinationExecutorReceivedButNoHooksIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperDestinationExecutor.contract.FilterLogs(opts, "SuperDestinationExecutorReceivedButNoHooks", accountRule)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationExecutorSuperDestinationExecutorReceivedButNoHooksIterator{contract: _SuperDestinationExecutor.contract, event: "SuperDestinationExecutorReceivedButNoHooks", logs: logs, sub: sub}, nil
}

// WatchSuperDestinationExecutorReceivedButNoHooks is a free log subscription operation binding the contract event 0xb159537e384a9a796d3957f8a925c701e1a32cb359781d4b26ac895b02125f78.
//
// Solidity: event SuperDestinationExecutorReceivedButNoHooks(address indexed account)
func (_SuperDestinationExecutor *SuperDestinationExecutorFilterer) WatchSuperDestinationExecutorReceivedButNoHooks(opts *bind.WatchOpts, sink chan<- *SuperDestinationExecutorSuperDestinationExecutorReceivedButNoHooks, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperDestinationExecutor.contract.WatchLogs(opts, "SuperDestinationExecutorReceivedButNoHooks", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperDestinationExecutorSuperDestinationExecutorReceivedButNoHooks)
				if err := _SuperDestinationExecutor.contract.UnpackLog(event, "SuperDestinationExecutorReceivedButNoHooks", log); err != nil {
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

// ParseSuperDestinationExecutorReceivedButNoHooks is a log parse operation binding the contract event 0xb159537e384a9a796d3957f8a925c701e1a32cb359781d4b26ac895b02125f78.
//
// Solidity: event SuperDestinationExecutorReceivedButNoHooks(address indexed account)
func (_SuperDestinationExecutor *SuperDestinationExecutorFilterer) ParseSuperDestinationExecutorReceivedButNoHooks(log types.Log) (*SuperDestinationExecutorSuperDestinationExecutorReceivedButNoHooks, error) {
	event := new(SuperDestinationExecutorSuperDestinationExecutorReceivedButNoHooks)
	if err := _SuperDestinationExecutor.contract.UnpackLog(event, "SuperDestinationExecutorReceivedButNoHooks", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalanceIterator is returned from FilterSuperDestinationExecutorReceivedButNotEnoughBalance and is used to iterate over the raw logs and unpacked data for SuperDestinationExecutorReceivedButNotEnoughBalance events raised by the SuperDestinationExecutor contract.
type SuperDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalanceIterator struct {
	Event *SuperDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalance // Event containing the contract specifics and raw log

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
func (it *SuperDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalanceIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalance)
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
		it.Event = new(SuperDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalance)
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
func (it *SuperDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalanceIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalanceIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalance represents a SuperDestinationExecutorReceivedButNotEnoughBalance event raised by the SuperDestinationExecutor contract.
type SuperDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalance struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterSuperDestinationExecutorReceivedButNotEnoughBalance is a free log retrieval operation binding the contract event 0x6163b8ae4cc2268589b5eece18135082decde1f16bfd85daf04fb457e717705b.
//
// Solidity: event SuperDestinationExecutorReceivedButNotEnoughBalance(address indexed account)
func (_SuperDestinationExecutor *SuperDestinationExecutorFilterer) FilterSuperDestinationExecutorReceivedButNotEnoughBalance(opts *bind.FilterOpts, account []common.Address) (*SuperDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalanceIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperDestinationExecutor.contract.FilterLogs(opts, "SuperDestinationExecutorReceivedButNotEnoughBalance", accountRule)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalanceIterator{contract: _SuperDestinationExecutor.contract, event: "SuperDestinationExecutorReceivedButNotEnoughBalance", logs: logs, sub: sub}, nil
}

// WatchSuperDestinationExecutorReceivedButNotEnoughBalance is a free log subscription operation binding the contract event 0x6163b8ae4cc2268589b5eece18135082decde1f16bfd85daf04fb457e717705b.
//
// Solidity: event SuperDestinationExecutorReceivedButNotEnoughBalance(address indexed account)
func (_SuperDestinationExecutor *SuperDestinationExecutorFilterer) WatchSuperDestinationExecutorReceivedButNotEnoughBalance(opts *bind.WatchOpts, sink chan<- *SuperDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalance, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperDestinationExecutor.contract.WatchLogs(opts, "SuperDestinationExecutorReceivedButNotEnoughBalance", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalance)
				if err := _SuperDestinationExecutor.contract.UnpackLog(event, "SuperDestinationExecutorReceivedButNotEnoughBalance", log); err != nil {
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

// ParseSuperDestinationExecutorReceivedButNotEnoughBalance is a log parse operation binding the contract event 0x6163b8ae4cc2268589b5eece18135082decde1f16bfd85daf04fb457e717705b.
//
// Solidity: event SuperDestinationExecutorReceivedButNotEnoughBalance(address indexed account)
func (_SuperDestinationExecutor *SuperDestinationExecutorFilterer) ParseSuperDestinationExecutorReceivedButNotEnoughBalance(log types.Log) (*SuperDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalance, error) {
	event := new(SuperDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalance)
	if err := _SuperDestinationExecutor.contract.UnpackLog(event, "SuperDestinationExecutorReceivedButNotEnoughBalance", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperDestinationExecutorSuperPositionLockedIterator is returned from FilterSuperPositionLocked and is used to iterate over the raw logs and unpacked data for SuperPositionLocked events raised by the SuperDestinationExecutor contract.
type SuperDestinationExecutorSuperPositionLockedIterator struct {
	Event *SuperDestinationExecutorSuperPositionLocked // Event containing the contract specifics and raw log

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
func (it *SuperDestinationExecutorSuperPositionLockedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperDestinationExecutorSuperPositionLocked)
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
		it.Event = new(SuperDestinationExecutorSuperPositionLocked)
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
func (it *SuperDestinationExecutorSuperPositionLockedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperDestinationExecutorSuperPositionLockedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperDestinationExecutorSuperPositionLocked represents a SuperPositionLocked event raised by the SuperDestinationExecutor contract.
type SuperDestinationExecutorSuperPositionLocked struct {
	Account common.Address
	SpToken common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterSuperPositionLocked is a free log retrieval operation binding the contract event 0xdf09bac395df649ca72fb3ffb451d40c290e25dcef3002e19d2c04ce09441b9b.
//
// Solidity: event SuperPositionLocked(address indexed account, address indexed spToken, uint256 amount)
func (_SuperDestinationExecutor *SuperDestinationExecutorFilterer) FilterSuperPositionLocked(opts *bind.FilterOpts, account []common.Address, spToken []common.Address) (*SuperDestinationExecutorSuperPositionLockedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var spTokenRule []interface{}
	for _, spTokenItem := range spToken {
		spTokenRule = append(spTokenRule, spTokenItem)
	}

	logs, sub, err := _SuperDestinationExecutor.contract.FilterLogs(opts, "SuperPositionLocked", accountRule, spTokenRule)
	if err != nil {
		return nil, err
	}
	return &SuperDestinationExecutorSuperPositionLockedIterator{contract: _SuperDestinationExecutor.contract, event: "SuperPositionLocked", logs: logs, sub: sub}, nil
}

// WatchSuperPositionLocked is a free log subscription operation binding the contract event 0xdf09bac395df649ca72fb3ffb451d40c290e25dcef3002e19d2c04ce09441b9b.
//
// Solidity: event SuperPositionLocked(address indexed account, address indexed spToken, uint256 amount)
func (_SuperDestinationExecutor *SuperDestinationExecutorFilterer) WatchSuperPositionLocked(opts *bind.WatchOpts, sink chan<- *SuperDestinationExecutorSuperPositionLocked, account []common.Address, spToken []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var spTokenRule []interface{}
	for _, spTokenItem := range spToken {
		spTokenRule = append(spTokenRule, spTokenItem)
	}

	logs, sub, err := _SuperDestinationExecutor.contract.WatchLogs(opts, "SuperPositionLocked", accountRule, spTokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperDestinationExecutorSuperPositionLocked)
				if err := _SuperDestinationExecutor.contract.UnpackLog(event, "SuperPositionLocked", log); err != nil {
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
func (_SuperDestinationExecutor *SuperDestinationExecutorFilterer) ParseSuperPositionLocked(log types.Log) (*SuperDestinationExecutorSuperPositionLocked, error) {
	event := new(SuperDestinationExecutorSuperPositionLocked)
	if err := _SuperDestinationExecutor.contract.UnpackLog(event, "SuperPositionLocked", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
