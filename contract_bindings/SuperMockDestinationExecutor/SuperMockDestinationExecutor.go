// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperMockDestinationExecutor

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

// SuperMockDestinationExecutorMetaData contains all meta data concerning the SuperMockDestinationExecutor contract.
var SuperMockDestinationExecutorMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"ledgerConfiguration_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"superDestinationValidator_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"SUPER_DESTINATION_VALIDATOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"execute\",\"inputs\":[{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isInitialized\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isMerkleRootUsed\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"merkleRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isModuleType\",\"inputs\":[{\"name\":\"typeId\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"ledgerConfiguration\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"markRootsAsUsed\",\"inputs\":[{\"name\":\"roots\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"name\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"onInstall\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"onUninstall\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"processBridgedExecution\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"dstTokens\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"intentAmounts\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"initData\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"executorCalldata\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"userSignatureData\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"usedMerkleRoots\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"merkleRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"used\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"validateHookCompliance\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"prevHook\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"hookData\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple[]\",\"internalType\":\"structExecution[]\",\"components\":[{\"name\":\"target\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"callData\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"version\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"pure\"},{\"type\":\"event\",\"name\":\"AccountCreated\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"salt\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperDestinationExecutorExecuted\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperDestinationExecutorInvalidIntentAmount\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"intentAmount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperDestinationExecutorMarkRootsAsUsed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"roots\",\"type\":\"bytes32[]\",\"indexed\":false,\"internalType\":\"bytes32[]\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperDestinationExecutorReceivedButNoHooks\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperDestinationExecutorReceivedButNotEnoughBalance\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"intentAmount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"available\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperDestinationExecutorReceivedButRootUsedAlready\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"root\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperPositionMintRequested\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"spToken\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"dstChainId\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCOUNT_NOT_CREATED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_ACCOUNT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ALREADY_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ARRAY_LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FEE_NOT_TRANSFERRED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_BALANCE_FOR_FEE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_ACCOUNT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_CALLER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_CHAIN_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_FEE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_SIGNATURE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_YIELD_SOURCE_ORACLE_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MALICIOUS_HOOK_DETECTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MANAGER_NOT_SET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MERKLE_ROOT_ALREADY_USED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ModuleAlreadyInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"NOT_AUTHORIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_HOOKS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"ReentrancyGuardReentrantCall\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SENDER_CREATOR_NOT_VALID\",\"inputs\":[]}]",
}

// SuperMockDestinationExecutorABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperMockDestinationExecutorMetaData.ABI instead.
var SuperMockDestinationExecutorABI = SuperMockDestinationExecutorMetaData.ABI

// SuperMockDestinationExecutor is an auto generated Go binding around an Ethereum contract.
type SuperMockDestinationExecutor struct {
	SuperMockDestinationExecutorCaller     // Read-only binding to the contract
	SuperMockDestinationExecutorTransactor // Write-only binding to the contract
	SuperMockDestinationExecutorFilterer   // Log filterer for contract events
}

// SuperMockDestinationExecutorCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperMockDestinationExecutorCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperMockDestinationExecutorTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperMockDestinationExecutorTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperMockDestinationExecutorFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperMockDestinationExecutorFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperMockDestinationExecutorSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperMockDestinationExecutorSession struct {
	Contract     *SuperMockDestinationExecutor // Generic contract binding to set the session for
	CallOpts     bind.CallOpts                 // Call options to use throughout this session
	TransactOpts bind.TransactOpts             // Transaction auth options to use throughout this session
}

// SuperMockDestinationExecutorCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperMockDestinationExecutorCallerSession struct {
	Contract *SuperMockDestinationExecutorCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                       // Call options to use throughout this session
}

// SuperMockDestinationExecutorTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperMockDestinationExecutorTransactorSession struct {
	Contract     *SuperMockDestinationExecutorTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                       // Transaction auth options to use throughout this session
}

// SuperMockDestinationExecutorRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperMockDestinationExecutorRaw struct {
	Contract *SuperMockDestinationExecutor // Generic contract binding to access the raw methods on
}

// SuperMockDestinationExecutorCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperMockDestinationExecutorCallerRaw struct {
	Contract *SuperMockDestinationExecutorCaller // Generic read-only contract binding to access the raw methods on
}

// SuperMockDestinationExecutorTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperMockDestinationExecutorTransactorRaw struct {
	Contract *SuperMockDestinationExecutorTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperMockDestinationExecutor creates a new instance of SuperMockDestinationExecutor, bound to a specific deployed contract.
func NewSuperMockDestinationExecutor(address common.Address, backend bind.ContractBackend) (*SuperMockDestinationExecutor, error) {
	contract, err := bindSuperMockDestinationExecutor(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperMockDestinationExecutor{SuperMockDestinationExecutorCaller: SuperMockDestinationExecutorCaller{contract: contract}, SuperMockDestinationExecutorTransactor: SuperMockDestinationExecutorTransactor{contract: contract}, SuperMockDestinationExecutorFilterer: SuperMockDestinationExecutorFilterer{contract: contract}}, nil
}

// NewSuperMockDestinationExecutorCaller creates a new read-only instance of SuperMockDestinationExecutor, bound to a specific deployed contract.
func NewSuperMockDestinationExecutorCaller(address common.Address, caller bind.ContractCaller) (*SuperMockDestinationExecutorCaller, error) {
	contract, err := bindSuperMockDestinationExecutor(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperMockDestinationExecutorCaller{contract: contract}, nil
}

// NewSuperMockDestinationExecutorTransactor creates a new write-only instance of SuperMockDestinationExecutor, bound to a specific deployed contract.
func NewSuperMockDestinationExecutorTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperMockDestinationExecutorTransactor, error) {
	contract, err := bindSuperMockDestinationExecutor(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperMockDestinationExecutorTransactor{contract: contract}, nil
}

// NewSuperMockDestinationExecutorFilterer creates a new log filterer instance of SuperMockDestinationExecutor, bound to a specific deployed contract.
func NewSuperMockDestinationExecutorFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperMockDestinationExecutorFilterer, error) {
	contract, err := bindSuperMockDestinationExecutor(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperMockDestinationExecutorFilterer{contract: contract}, nil
}

// bindSuperMockDestinationExecutor binds a generic wrapper to an already deployed contract.
func bindSuperMockDestinationExecutor(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperMockDestinationExecutorMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperMockDestinationExecutor.Contract.SuperMockDestinationExecutorCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperMockDestinationExecutor.Contract.SuperMockDestinationExecutorTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperMockDestinationExecutor.Contract.SuperMockDestinationExecutorTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperMockDestinationExecutor.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperMockDestinationExecutor.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperMockDestinationExecutor.Contract.contract.Transact(opts, method, params...)
}

// SUPERDESTINATIONVALIDATOR is a free data retrieval call binding the contract method 0x5a0ed186.
//
// Solidity: function SUPER_DESTINATION_VALIDATOR() view returns(address)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorCaller) SUPERDESTINATIONVALIDATOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperMockDestinationExecutor.contract.Call(opts, &out, "SUPER_DESTINATION_VALIDATOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERDESTINATIONVALIDATOR is a free data retrieval call binding the contract method 0x5a0ed186.
//
// Solidity: function SUPER_DESTINATION_VALIDATOR() view returns(address)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorSession) SUPERDESTINATIONVALIDATOR() (common.Address, error) {
	return _SuperMockDestinationExecutor.Contract.SUPERDESTINATIONVALIDATOR(&_SuperMockDestinationExecutor.CallOpts)
}

// SUPERDESTINATIONVALIDATOR is a free data retrieval call binding the contract method 0x5a0ed186.
//
// Solidity: function SUPER_DESTINATION_VALIDATOR() view returns(address)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorCallerSession) SUPERDESTINATIONVALIDATOR() (common.Address, error) {
	return _SuperMockDestinationExecutor.Contract.SUPERDESTINATIONVALIDATOR(&_SuperMockDestinationExecutor.CallOpts)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorCaller) IsInitialized(opts *bind.CallOpts, account common.Address) (bool, error) {
	var out []interface{}
	err := _SuperMockDestinationExecutor.contract.Call(opts, &out, "isInitialized", account)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperMockDestinationExecutor.Contract.IsInitialized(&_SuperMockDestinationExecutor.CallOpts, account)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorCallerSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperMockDestinationExecutor.Contract.IsInitialized(&_SuperMockDestinationExecutor.CallOpts, account)
}

// IsMerkleRootUsed is a free data retrieval call binding the contract method 0x244cd767.
//
// Solidity: function isMerkleRootUsed(address user, bytes32 merkleRoot) view returns(bool)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorCaller) IsMerkleRootUsed(opts *bind.CallOpts, user common.Address, merkleRoot [32]byte) (bool, error) {
	var out []interface{}
	err := _SuperMockDestinationExecutor.contract.Call(opts, &out, "isMerkleRootUsed", user, merkleRoot)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsMerkleRootUsed is a free data retrieval call binding the contract method 0x244cd767.
//
// Solidity: function isMerkleRootUsed(address user, bytes32 merkleRoot) view returns(bool)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorSession) IsMerkleRootUsed(user common.Address, merkleRoot [32]byte) (bool, error) {
	return _SuperMockDestinationExecutor.Contract.IsMerkleRootUsed(&_SuperMockDestinationExecutor.CallOpts, user, merkleRoot)
}

// IsMerkleRootUsed is a free data retrieval call binding the contract method 0x244cd767.
//
// Solidity: function isMerkleRootUsed(address user, bytes32 merkleRoot) view returns(bool)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorCallerSession) IsMerkleRootUsed(user common.Address, merkleRoot [32]byte) (bool, error) {
	return _SuperMockDestinationExecutor.Contract.IsMerkleRootUsed(&_SuperMockDestinationExecutor.CallOpts, user, merkleRoot)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeId) pure returns(bool)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorCaller) IsModuleType(opts *bind.CallOpts, typeId *big.Int) (bool, error) {
	var out []interface{}
	err := _SuperMockDestinationExecutor.contract.Call(opts, &out, "isModuleType", typeId)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeId) pure returns(bool)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorSession) IsModuleType(typeId *big.Int) (bool, error) {
	return _SuperMockDestinationExecutor.Contract.IsModuleType(&_SuperMockDestinationExecutor.CallOpts, typeId)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeId) pure returns(bool)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorCallerSession) IsModuleType(typeId *big.Int) (bool, error) {
	return _SuperMockDestinationExecutor.Contract.IsModuleType(&_SuperMockDestinationExecutor.CallOpts, typeId)
}

// LedgerConfiguration is a free data retrieval call binding the contract method 0x6740419b.
//
// Solidity: function ledgerConfiguration() view returns(address)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorCaller) LedgerConfiguration(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperMockDestinationExecutor.contract.Call(opts, &out, "ledgerConfiguration")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// LedgerConfiguration is a free data retrieval call binding the contract method 0x6740419b.
//
// Solidity: function ledgerConfiguration() view returns(address)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorSession) LedgerConfiguration() (common.Address, error) {
	return _SuperMockDestinationExecutor.Contract.LedgerConfiguration(&_SuperMockDestinationExecutor.CallOpts)
}

// LedgerConfiguration is a free data retrieval call binding the contract method 0x6740419b.
//
// Solidity: function ledgerConfiguration() view returns(address)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorCallerSession) LedgerConfiguration() (common.Address, error) {
	return _SuperMockDestinationExecutor.Contract.LedgerConfiguration(&_SuperMockDestinationExecutor.CallOpts)
}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() pure returns(string)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorCaller) Name(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperMockDestinationExecutor.contract.Call(opts, &out, "name")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() pure returns(string)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorSession) Name() (string, error) {
	return _SuperMockDestinationExecutor.Contract.Name(&_SuperMockDestinationExecutor.CallOpts)
}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() pure returns(string)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorCallerSession) Name() (string, error) {
	return _SuperMockDestinationExecutor.Contract.Name(&_SuperMockDestinationExecutor.CallOpts)
}

// UsedMerkleRoots is a free data retrieval call binding the contract method 0xa5b6f208.
//
// Solidity: function usedMerkleRoots(address user, bytes32 merkleRoot) view returns(bool used)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorCaller) UsedMerkleRoots(opts *bind.CallOpts, user common.Address, merkleRoot [32]byte) (bool, error) {
	var out []interface{}
	err := _SuperMockDestinationExecutor.contract.Call(opts, &out, "usedMerkleRoots", user, merkleRoot)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// UsedMerkleRoots is a free data retrieval call binding the contract method 0xa5b6f208.
//
// Solidity: function usedMerkleRoots(address user, bytes32 merkleRoot) view returns(bool used)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorSession) UsedMerkleRoots(user common.Address, merkleRoot [32]byte) (bool, error) {
	return _SuperMockDestinationExecutor.Contract.UsedMerkleRoots(&_SuperMockDestinationExecutor.CallOpts, user, merkleRoot)
}

// UsedMerkleRoots is a free data retrieval call binding the contract method 0xa5b6f208.
//
// Solidity: function usedMerkleRoots(address user, bytes32 merkleRoot) view returns(bool used)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorCallerSession) UsedMerkleRoots(user common.Address, merkleRoot [32]byte) (bool, error) {
	return _SuperMockDestinationExecutor.Contract.UsedMerkleRoots(&_SuperMockDestinationExecutor.CallOpts, user, merkleRoot)
}

// ValidateHookCompliance is a free data retrieval call binding the contract method 0x4a03fda4.
//
// Solidity: function validateHookCompliance(address hook, address prevHook, address account, bytes hookData) view returns((address,uint256,bytes)[])
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorCaller) ValidateHookCompliance(opts *bind.CallOpts, hook common.Address, prevHook common.Address, account common.Address, hookData []byte) ([]Execution, error) {
	var out []interface{}
	err := _SuperMockDestinationExecutor.contract.Call(opts, &out, "validateHookCompliance", hook, prevHook, account, hookData)

	if err != nil {
		return *new([]Execution), err
	}

	out0 := *abi.ConvertType(out[0], new([]Execution)).(*[]Execution)

	return out0, err

}

// ValidateHookCompliance is a free data retrieval call binding the contract method 0x4a03fda4.
//
// Solidity: function validateHookCompliance(address hook, address prevHook, address account, bytes hookData) view returns((address,uint256,bytes)[])
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorSession) ValidateHookCompliance(hook common.Address, prevHook common.Address, account common.Address, hookData []byte) ([]Execution, error) {
	return _SuperMockDestinationExecutor.Contract.ValidateHookCompliance(&_SuperMockDestinationExecutor.CallOpts, hook, prevHook, account, hookData)
}

// ValidateHookCompliance is a free data retrieval call binding the contract method 0x4a03fda4.
//
// Solidity: function validateHookCompliance(address hook, address prevHook, address account, bytes hookData) view returns((address,uint256,bytes)[])
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorCallerSession) ValidateHookCompliance(hook common.Address, prevHook common.Address, account common.Address, hookData []byte) ([]Execution, error) {
	return _SuperMockDestinationExecutor.Contract.ValidateHookCompliance(&_SuperMockDestinationExecutor.CallOpts, hook, prevHook, account, hookData)
}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() pure returns(string)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorCaller) Version(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperMockDestinationExecutor.contract.Call(opts, &out, "version")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() pure returns(string)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorSession) Version() (string, error) {
	return _SuperMockDestinationExecutor.Contract.Version(&_SuperMockDestinationExecutor.CallOpts)
}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() pure returns(string)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorCallerSession) Version() (string, error) {
	return _SuperMockDestinationExecutor.Contract.Version(&_SuperMockDestinationExecutor.CallOpts)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorTransactor) Execute(opts *bind.TransactOpts, data []byte) (*types.Transaction, error) {
	return _SuperMockDestinationExecutor.contract.Transact(opts, "execute", data)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorSession) Execute(data []byte) (*types.Transaction, error) {
	return _SuperMockDestinationExecutor.Contract.Execute(&_SuperMockDestinationExecutor.TransactOpts, data)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorTransactorSession) Execute(data []byte) (*types.Transaction, error) {
	return _SuperMockDestinationExecutor.Contract.Execute(&_SuperMockDestinationExecutor.TransactOpts, data)
}

// MarkRootsAsUsed is a paid mutator transaction binding the contract method 0xa5c08d3d.
//
// Solidity: function markRootsAsUsed(bytes32[] roots) returns()
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorTransactor) MarkRootsAsUsed(opts *bind.TransactOpts, roots [][32]byte) (*types.Transaction, error) {
	return _SuperMockDestinationExecutor.contract.Transact(opts, "markRootsAsUsed", roots)
}

// MarkRootsAsUsed is a paid mutator transaction binding the contract method 0xa5c08d3d.
//
// Solidity: function markRootsAsUsed(bytes32[] roots) returns()
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorSession) MarkRootsAsUsed(roots [][32]byte) (*types.Transaction, error) {
	return _SuperMockDestinationExecutor.Contract.MarkRootsAsUsed(&_SuperMockDestinationExecutor.TransactOpts, roots)
}

// MarkRootsAsUsed is a paid mutator transaction binding the contract method 0xa5c08d3d.
//
// Solidity: function markRootsAsUsed(bytes32[] roots) returns()
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorTransactorSession) MarkRootsAsUsed(roots [][32]byte) (*types.Transaction, error) {
	return _SuperMockDestinationExecutor.Contract.MarkRootsAsUsed(&_SuperMockDestinationExecutor.TransactOpts, roots)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorTransactor) OnInstall(opts *bind.TransactOpts, arg0 []byte) (*types.Transaction, error) {
	return _SuperMockDestinationExecutor.contract.Transact(opts, "onInstall", arg0)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorSession) OnInstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperMockDestinationExecutor.Contract.OnInstall(&_SuperMockDestinationExecutor.TransactOpts, arg0)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorTransactorSession) OnInstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperMockDestinationExecutor.Contract.OnInstall(&_SuperMockDestinationExecutor.TransactOpts, arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorTransactor) OnUninstall(opts *bind.TransactOpts, arg0 []byte) (*types.Transaction, error) {
	return _SuperMockDestinationExecutor.contract.Transact(opts, "onUninstall", arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperMockDestinationExecutor.Contract.OnUninstall(&_SuperMockDestinationExecutor.TransactOpts, arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorTransactorSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperMockDestinationExecutor.Contract.OnUninstall(&_SuperMockDestinationExecutor.TransactOpts, arg0)
}

// ProcessBridgedExecution is a paid mutator transaction binding the contract method 0xed71d9d1.
//
// Solidity: function processBridgedExecution(address , address account, address[] dstTokens, uint256[] intentAmounts, bytes initData, bytes executorCalldata, bytes userSignatureData) returns()
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorTransactor) ProcessBridgedExecution(opts *bind.TransactOpts, arg0 common.Address, account common.Address, dstTokens []common.Address, intentAmounts []*big.Int, initData []byte, executorCalldata []byte, userSignatureData []byte) (*types.Transaction, error) {
	return _SuperMockDestinationExecutor.contract.Transact(opts, "processBridgedExecution", arg0, account, dstTokens, intentAmounts, initData, executorCalldata, userSignatureData)
}

// ProcessBridgedExecution is a paid mutator transaction binding the contract method 0xed71d9d1.
//
// Solidity: function processBridgedExecution(address , address account, address[] dstTokens, uint256[] intentAmounts, bytes initData, bytes executorCalldata, bytes userSignatureData) returns()
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorSession) ProcessBridgedExecution(arg0 common.Address, account common.Address, dstTokens []common.Address, intentAmounts []*big.Int, initData []byte, executorCalldata []byte, userSignatureData []byte) (*types.Transaction, error) {
	return _SuperMockDestinationExecutor.Contract.ProcessBridgedExecution(&_SuperMockDestinationExecutor.TransactOpts, arg0, account, dstTokens, intentAmounts, initData, executorCalldata, userSignatureData)
}

// ProcessBridgedExecution is a paid mutator transaction binding the contract method 0xed71d9d1.
//
// Solidity: function processBridgedExecution(address , address account, address[] dstTokens, uint256[] intentAmounts, bytes initData, bytes executorCalldata, bytes userSignatureData) returns()
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorTransactorSession) ProcessBridgedExecution(arg0 common.Address, account common.Address, dstTokens []common.Address, intentAmounts []*big.Int, initData []byte, executorCalldata []byte, userSignatureData []byte) (*types.Transaction, error) {
	return _SuperMockDestinationExecutor.Contract.ProcessBridgedExecution(&_SuperMockDestinationExecutor.TransactOpts, arg0, account, dstTokens, intentAmounts, initData, executorCalldata, userSignatureData)
}

// SuperMockDestinationExecutorAccountCreatedIterator is returned from FilterAccountCreated and is used to iterate over the raw logs and unpacked data for AccountCreated events raised by the SuperMockDestinationExecutor contract.
type SuperMockDestinationExecutorAccountCreatedIterator struct {
	Event *SuperMockDestinationExecutorAccountCreated // Event containing the contract specifics and raw log

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
func (it *SuperMockDestinationExecutorAccountCreatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperMockDestinationExecutorAccountCreated)
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
		it.Event = new(SuperMockDestinationExecutorAccountCreated)
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
func (it *SuperMockDestinationExecutorAccountCreatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperMockDestinationExecutorAccountCreatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperMockDestinationExecutorAccountCreated represents a AccountCreated event raised by the SuperMockDestinationExecutor contract.
type SuperMockDestinationExecutorAccountCreated struct {
	Account common.Address
	Salt    [32]byte
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAccountCreated is a free log retrieval operation binding the contract event 0x8fe66a5d954d6d3e0306797e31e226812a9916895165c96c367ef52807631951.
//
// Solidity: event AccountCreated(address indexed account, bytes32 salt)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorFilterer) FilterAccountCreated(opts *bind.FilterOpts, account []common.Address) (*SuperMockDestinationExecutorAccountCreatedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperMockDestinationExecutor.contract.FilterLogs(opts, "AccountCreated", accountRule)
	if err != nil {
		return nil, err
	}
	return &SuperMockDestinationExecutorAccountCreatedIterator{contract: _SuperMockDestinationExecutor.contract, event: "AccountCreated", logs: logs, sub: sub}, nil
}

// WatchAccountCreated is a free log subscription operation binding the contract event 0x8fe66a5d954d6d3e0306797e31e226812a9916895165c96c367ef52807631951.
//
// Solidity: event AccountCreated(address indexed account, bytes32 salt)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorFilterer) WatchAccountCreated(opts *bind.WatchOpts, sink chan<- *SuperMockDestinationExecutorAccountCreated, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperMockDestinationExecutor.contract.WatchLogs(opts, "AccountCreated", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperMockDestinationExecutorAccountCreated)
				if err := _SuperMockDestinationExecutor.contract.UnpackLog(event, "AccountCreated", log); err != nil {
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
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorFilterer) ParseAccountCreated(log types.Log) (*SuperMockDestinationExecutorAccountCreated, error) {
	event := new(SuperMockDestinationExecutorAccountCreated)
	if err := _SuperMockDestinationExecutor.contract.UnpackLog(event, "AccountCreated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperMockDestinationExecutorSuperDestinationExecutorExecutedIterator is returned from FilterSuperDestinationExecutorExecuted and is used to iterate over the raw logs and unpacked data for SuperDestinationExecutorExecuted events raised by the SuperMockDestinationExecutor contract.
type SuperMockDestinationExecutorSuperDestinationExecutorExecutedIterator struct {
	Event *SuperMockDestinationExecutorSuperDestinationExecutorExecuted // Event containing the contract specifics and raw log

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
func (it *SuperMockDestinationExecutorSuperDestinationExecutorExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperMockDestinationExecutorSuperDestinationExecutorExecuted)
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
		it.Event = new(SuperMockDestinationExecutorSuperDestinationExecutorExecuted)
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
func (it *SuperMockDestinationExecutorSuperDestinationExecutorExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperMockDestinationExecutorSuperDestinationExecutorExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperMockDestinationExecutorSuperDestinationExecutorExecuted represents a SuperDestinationExecutorExecuted event raised by the SuperMockDestinationExecutor contract.
type SuperMockDestinationExecutorSuperDestinationExecutorExecuted struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterSuperDestinationExecutorExecuted is a free log retrieval operation binding the contract event 0x98f6e69f6c380877e68c669d19d23a062e9e5a9c18103278c08537aae6fd825e.
//
// Solidity: event SuperDestinationExecutorExecuted(address indexed account)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorFilterer) FilterSuperDestinationExecutorExecuted(opts *bind.FilterOpts, account []common.Address) (*SuperMockDestinationExecutorSuperDestinationExecutorExecutedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperMockDestinationExecutor.contract.FilterLogs(opts, "SuperDestinationExecutorExecuted", accountRule)
	if err != nil {
		return nil, err
	}
	return &SuperMockDestinationExecutorSuperDestinationExecutorExecutedIterator{contract: _SuperMockDestinationExecutor.contract, event: "SuperDestinationExecutorExecuted", logs: logs, sub: sub}, nil
}

// WatchSuperDestinationExecutorExecuted is a free log subscription operation binding the contract event 0x98f6e69f6c380877e68c669d19d23a062e9e5a9c18103278c08537aae6fd825e.
//
// Solidity: event SuperDestinationExecutorExecuted(address indexed account)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorFilterer) WatchSuperDestinationExecutorExecuted(opts *bind.WatchOpts, sink chan<- *SuperMockDestinationExecutorSuperDestinationExecutorExecuted, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperMockDestinationExecutor.contract.WatchLogs(opts, "SuperDestinationExecutorExecuted", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperMockDestinationExecutorSuperDestinationExecutorExecuted)
				if err := _SuperMockDestinationExecutor.contract.UnpackLog(event, "SuperDestinationExecutorExecuted", log); err != nil {
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
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorFilterer) ParseSuperDestinationExecutorExecuted(log types.Log) (*SuperMockDestinationExecutorSuperDestinationExecutorExecuted, error) {
	event := new(SuperMockDestinationExecutorSuperDestinationExecutorExecuted)
	if err := _SuperMockDestinationExecutor.contract.UnpackLog(event, "SuperDestinationExecutorExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperMockDestinationExecutorSuperDestinationExecutorInvalidIntentAmountIterator is returned from FilterSuperDestinationExecutorInvalidIntentAmount and is used to iterate over the raw logs and unpacked data for SuperDestinationExecutorInvalidIntentAmount events raised by the SuperMockDestinationExecutor contract.
type SuperMockDestinationExecutorSuperDestinationExecutorInvalidIntentAmountIterator struct {
	Event *SuperMockDestinationExecutorSuperDestinationExecutorInvalidIntentAmount // Event containing the contract specifics and raw log

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
func (it *SuperMockDestinationExecutorSuperDestinationExecutorInvalidIntentAmountIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperMockDestinationExecutorSuperDestinationExecutorInvalidIntentAmount)
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
		it.Event = new(SuperMockDestinationExecutorSuperDestinationExecutorInvalidIntentAmount)
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
func (it *SuperMockDestinationExecutorSuperDestinationExecutorInvalidIntentAmountIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperMockDestinationExecutorSuperDestinationExecutorInvalidIntentAmountIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperMockDestinationExecutorSuperDestinationExecutorInvalidIntentAmount represents a SuperDestinationExecutorInvalidIntentAmount event raised by the SuperMockDestinationExecutor contract.
type SuperMockDestinationExecutorSuperDestinationExecutorInvalidIntentAmount struct {
	Account      common.Address
	Token        common.Address
	IntentAmount *big.Int
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterSuperDestinationExecutorInvalidIntentAmount is a free log retrieval operation binding the contract event 0xfe3e30b591c8199a91f575b16b49e2d2b7d947c4e1490f570b41f1aa448decb8.
//
// Solidity: event SuperDestinationExecutorInvalidIntentAmount(address indexed account, address indexed token, uint256 intentAmount)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorFilterer) FilterSuperDestinationExecutorInvalidIntentAmount(opts *bind.FilterOpts, account []common.Address, token []common.Address) (*SuperMockDestinationExecutorSuperDestinationExecutorInvalidIntentAmountIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _SuperMockDestinationExecutor.contract.FilterLogs(opts, "SuperDestinationExecutorInvalidIntentAmount", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &SuperMockDestinationExecutorSuperDestinationExecutorInvalidIntentAmountIterator{contract: _SuperMockDestinationExecutor.contract, event: "SuperDestinationExecutorInvalidIntentAmount", logs: logs, sub: sub}, nil
}

// WatchSuperDestinationExecutorInvalidIntentAmount is a free log subscription operation binding the contract event 0xfe3e30b591c8199a91f575b16b49e2d2b7d947c4e1490f570b41f1aa448decb8.
//
// Solidity: event SuperDestinationExecutorInvalidIntentAmount(address indexed account, address indexed token, uint256 intentAmount)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorFilterer) WatchSuperDestinationExecutorInvalidIntentAmount(opts *bind.WatchOpts, sink chan<- *SuperMockDestinationExecutorSuperDestinationExecutorInvalidIntentAmount, account []common.Address, token []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _SuperMockDestinationExecutor.contract.WatchLogs(opts, "SuperDestinationExecutorInvalidIntentAmount", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperMockDestinationExecutorSuperDestinationExecutorInvalidIntentAmount)
				if err := _SuperMockDestinationExecutor.contract.UnpackLog(event, "SuperDestinationExecutorInvalidIntentAmount", log); err != nil {
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

// ParseSuperDestinationExecutorInvalidIntentAmount is a log parse operation binding the contract event 0xfe3e30b591c8199a91f575b16b49e2d2b7d947c4e1490f570b41f1aa448decb8.
//
// Solidity: event SuperDestinationExecutorInvalidIntentAmount(address indexed account, address indexed token, uint256 intentAmount)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorFilterer) ParseSuperDestinationExecutorInvalidIntentAmount(log types.Log) (*SuperMockDestinationExecutorSuperDestinationExecutorInvalidIntentAmount, error) {
	event := new(SuperMockDestinationExecutorSuperDestinationExecutorInvalidIntentAmount)
	if err := _SuperMockDestinationExecutor.contract.UnpackLog(event, "SuperDestinationExecutorInvalidIntentAmount", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperMockDestinationExecutorSuperDestinationExecutorMarkRootsAsUsedIterator is returned from FilterSuperDestinationExecutorMarkRootsAsUsed and is used to iterate over the raw logs and unpacked data for SuperDestinationExecutorMarkRootsAsUsed events raised by the SuperMockDestinationExecutor contract.
type SuperMockDestinationExecutorSuperDestinationExecutorMarkRootsAsUsedIterator struct {
	Event *SuperMockDestinationExecutorSuperDestinationExecutorMarkRootsAsUsed // Event containing the contract specifics and raw log

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
func (it *SuperMockDestinationExecutorSuperDestinationExecutorMarkRootsAsUsedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperMockDestinationExecutorSuperDestinationExecutorMarkRootsAsUsed)
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
		it.Event = new(SuperMockDestinationExecutorSuperDestinationExecutorMarkRootsAsUsed)
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
func (it *SuperMockDestinationExecutorSuperDestinationExecutorMarkRootsAsUsedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperMockDestinationExecutorSuperDestinationExecutorMarkRootsAsUsedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperMockDestinationExecutorSuperDestinationExecutorMarkRootsAsUsed represents a SuperDestinationExecutorMarkRootsAsUsed event raised by the SuperMockDestinationExecutor contract.
type SuperMockDestinationExecutorSuperDestinationExecutorMarkRootsAsUsed struct {
	Account common.Address
	Roots   [][32]byte
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterSuperDestinationExecutorMarkRootsAsUsed is a free log retrieval operation binding the contract event 0x2a2e76694cfe1777579407d33b992a385876cdac566ec14689232edd2425d40e.
//
// Solidity: event SuperDestinationExecutorMarkRootsAsUsed(address indexed account, bytes32[] roots)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorFilterer) FilterSuperDestinationExecutorMarkRootsAsUsed(opts *bind.FilterOpts, account []common.Address) (*SuperMockDestinationExecutorSuperDestinationExecutorMarkRootsAsUsedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperMockDestinationExecutor.contract.FilterLogs(opts, "SuperDestinationExecutorMarkRootsAsUsed", accountRule)
	if err != nil {
		return nil, err
	}
	return &SuperMockDestinationExecutorSuperDestinationExecutorMarkRootsAsUsedIterator{contract: _SuperMockDestinationExecutor.contract, event: "SuperDestinationExecutorMarkRootsAsUsed", logs: logs, sub: sub}, nil
}

// WatchSuperDestinationExecutorMarkRootsAsUsed is a free log subscription operation binding the contract event 0x2a2e76694cfe1777579407d33b992a385876cdac566ec14689232edd2425d40e.
//
// Solidity: event SuperDestinationExecutorMarkRootsAsUsed(address indexed account, bytes32[] roots)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorFilterer) WatchSuperDestinationExecutorMarkRootsAsUsed(opts *bind.WatchOpts, sink chan<- *SuperMockDestinationExecutorSuperDestinationExecutorMarkRootsAsUsed, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperMockDestinationExecutor.contract.WatchLogs(opts, "SuperDestinationExecutorMarkRootsAsUsed", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperMockDestinationExecutorSuperDestinationExecutorMarkRootsAsUsed)
				if err := _SuperMockDestinationExecutor.contract.UnpackLog(event, "SuperDestinationExecutorMarkRootsAsUsed", log); err != nil {
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

// ParseSuperDestinationExecutorMarkRootsAsUsed is a log parse operation binding the contract event 0x2a2e76694cfe1777579407d33b992a385876cdac566ec14689232edd2425d40e.
//
// Solidity: event SuperDestinationExecutorMarkRootsAsUsed(address indexed account, bytes32[] roots)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorFilterer) ParseSuperDestinationExecutorMarkRootsAsUsed(log types.Log) (*SuperMockDestinationExecutorSuperDestinationExecutorMarkRootsAsUsed, error) {
	event := new(SuperMockDestinationExecutorSuperDestinationExecutorMarkRootsAsUsed)
	if err := _SuperMockDestinationExecutor.contract.UnpackLog(event, "SuperDestinationExecutorMarkRootsAsUsed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNoHooksIterator is returned from FilterSuperDestinationExecutorReceivedButNoHooks and is used to iterate over the raw logs and unpacked data for SuperDestinationExecutorReceivedButNoHooks events raised by the SuperMockDestinationExecutor contract.
type SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNoHooksIterator struct {
	Event *SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNoHooks // Event containing the contract specifics and raw log

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
func (it *SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNoHooksIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNoHooks)
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
		it.Event = new(SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNoHooks)
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
func (it *SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNoHooksIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNoHooksIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNoHooks represents a SuperDestinationExecutorReceivedButNoHooks event raised by the SuperMockDestinationExecutor contract.
type SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNoHooks struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterSuperDestinationExecutorReceivedButNoHooks is a free log retrieval operation binding the contract event 0xb159537e384a9a796d3957f8a925c701e1a32cb359781d4b26ac895b02125f78.
//
// Solidity: event SuperDestinationExecutorReceivedButNoHooks(address indexed account)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorFilterer) FilterSuperDestinationExecutorReceivedButNoHooks(opts *bind.FilterOpts, account []common.Address) (*SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNoHooksIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperMockDestinationExecutor.contract.FilterLogs(opts, "SuperDestinationExecutorReceivedButNoHooks", accountRule)
	if err != nil {
		return nil, err
	}
	return &SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNoHooksIterator{contract: _SuperMockDestinationExecutor.contract, event: "SuperDestinationExecutorReceivedButNoHooks", logs: logs, sub: sub}, nil
}

// WatchSuperDestinationExecutorReceivedButNoHooks is a free log subscription operation binding the contract event 0xb159537e384a9a796d3957f8a925c701e1a32cb359781d4b26ac895b02125f78.
//
// Solidity: event SuperDestinationExecutorReceivedButNoHooks(address indexed account)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorFilterer) WatchSuperDestinationExecutorReceivedButNoHooks(opts *bind.WatchOpts, sink chan<- *SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNoHooks, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _SuperMockDestinationExecutor.contract.WatchLogs(opts, "SuperDestinationExecutorReceivedButNoHooks", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNoHooks)
				if err := _SuperMockDestinationExecutor.contract.UnpackLog(event, "SuperDestinationExecutorReceivedButNoHooks", log); err != nil {
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
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorFilterer) ParseSuperDestinationExecutorReceivedButNoHooks(log types.Log) (*SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNoHooks, error) {
	event := new(SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNoHooks)
	if err := _SuperMockDestinationExecutor.contract.UnpackLog(event, "SuperDestinationExecutorReceivedButNoHooks", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalanceIterator is returned from FilterSuperDestinationExecutorReceivedButNotEnoughBalance and is used to iterate over the raw logs and unpacked data for SuperDestinationExecutorReceivedButNotEnoughBalance events raised by the SuperMockDestinationExecutor contract.
type SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalanceIterator struct {
	Event *SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalance // Event containing the contract specifics and raw log

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
func (it *SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalanceIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalance)
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
		it.Event = new(SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalance)
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
func (it *SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalanceIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalanceIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalance represents a SuperDestinationExecutorReceivedButNotEnoughBalance event raised by the SuperMockDestinationExecutor contract.
type SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalance struct {
	Account      common.Address
	Token        common.Address
	IntentAmount *big.Int
	Available    *big.Int
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterSuperDestinationExecutorReceivedButNotEnoughBalance is a free log retrieval operation binding the contract event 0x2a147d47d8d7c5f6b2c7eebb350802ba5ed6008e8eb811f40b78d2090b329c86.
//
// Solidity: event SuperDestinationExecutorReceivedButNotEnoughBalance(address indexed account, address indexed token, uint256 intentAmount, uint256 available)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorFilterer) FilterSuperDestinationExecutorReceivedButNotEnoughBalance(opts *bind.FilterOpts, account []common.Address, token []common.Address) (*SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalanceIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _SuperMockDestinationExecutor.contract.FilterLogs(opts, "SuperDestinationExecutorReceivedButNotEnoughBalance", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalanceIterator{contract: _SuperMockDestinationExecutor.contract, event: "SuperDestinationExecutorReceivedButNotEnoughBalance", logs: logs, sub: sub}, nil
}

// WatchSuperDestinationExecutorReceivedButNotEnoughBalance is a free log subscription operation binding the contract event 0x2a147d47d8d7c5f6b2c7eebb350802ba5ed6008e8eb811f40b78d2090b329c86.
//
// Solidity: event SuperDestinationExecutorReceivedButNotEnoughBalance(address indexed account, address indexed token, uint256 intentAmount, uint256 available)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorFilterer) WatchSuperDestinationExecutorReceivedButNotEnoughBalance(opts *bind.WatchOpts, sink chan<- *SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalance, account []common.Address, token []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _SuperMockDestinationExecutor.contract.WatchLogs(opts, "SuperDestinationExecutorReceivedButNotEnoughBalance", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalance)
				if err := _SuperMockDestinationExecutor.contract.UnpackLog(event, "SuperDestinationExecutorReceivedButNotEnoughBalance", log); err != nil {
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

// ParseSuperDestinationExecutorReceivedButNotEnoughBalance is a log parse operation binding the contract event 0x2a147d47d8d7c5f6b2c7eebb350802ba5ed6008e8eb811f40b78d2090b329c86.
//
// Solidity: event SuperDestinationExecutorReceivedButNotEnoughBalance(address indexed account, address indexed token, uint256 intentAmount, uint256 available)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorFilterer) ParseSuperDestinationExecutorReceivedButNotEnoughBalance(log types.Log) (*SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalance, error) {
	event := new(SuperMockDestinationExecutorSuperDestinationExecutorReceivedButNotEnoughBalance)
	if err := _SuperMockDestinationExecutor.contract.UnpackLog(event, "SuperDestinationExecutorReceivedButNotEnoughBalance", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperMockDestinationExecutorSuperDestinationExecutorReceivedButRootUsedAlreadyIterator is returned from FilterSuperDestinationExecutorReceivedButRootUsedAlready and is used to iterate over the raw logs and unpacked data for SuperDestinationExecutorReceivedButRootUsedAlready events raised by the SuperMockDestinationExecutor contract.
type SuperMockDestinationExecutorSuperDestinationExecutorReceivedButRootUsedAlreadyIterator struct {
	Event *SuperMockDestinationExecutorSuperDestinationExecutorReceivedButRootUsedAlready // Event containing the contract specifics and raw log

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
func (it *SuperMockDestinationExecutorSuperDestinationExecutorReceivedButRootUsedAlreadyIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperMockDestinationExecutorSuperDestinationExecutorReceivedButRootUsedAlready)
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
		it.Event = new(SuperMockDestinationExecutorSuperDestinationExecutorReceivedButRootUsedAlready)
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
func (it *SuperMockDestinationExecutorSuperDestinationExecutorReceivedButRootUsedAlreadyIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperMockDestinationExecutorSuperDestinationExecutorReceivedButRootUsedAlreadyIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperMockDestinationExecutorSuperDestinationExecutorReceivedButRootUsedAlready represents a SuperDestinationExecutorReceivedButRootUsedAlready event raised by the SuperMockDestinationExecutor contract.
type SuperMockDestinationExecutorSuperDestinationExecutorReceivedButRootUsedAlready struct {
	Account common.Address
	Root    [32]byte
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterSuperDestinationExecutorReceivedButRootUsedAlready is a free log retrieval operation binding the contract event 0xc85a4c9cf6ceb3da81d38c466e43c8b89a7f2857440772a73d2189d718b57841.
//
// Solidity: event SuperDestinationExecutorReceivedButRootUsedAlready(address indexed account, bytes32 indexed root)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorFilterer) FilterSuperDestinationExecutorReceivedButRootUsedAlready(opts *bind.FilterOpts, account []common.Address, root [][32]byte) (*SuperMockDestinationExecutorSuperDestinationExecutorReceivedButRootUsedAlreadyIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var rootRule []interface{}
	for _, rootItem := range root {
		rootRule = append(rootRule, rootItem)
	}

	logs, sub, err := _SuperMockDestinationExecutor.contract.FilterLogs(opts, "SuperDestinationExecutorReceivedButRootUsedAlready", accountRule, rootRule)
	if err != nil {
		return nil, err
	}
	return &SuperMockDestinationExecutorSuperDestinationExecutorReceivedButRootUsedAlreadyIterator{contract: _SuperMockDestinationExecutor.contract, event: "SuperDestinationExecutorReceivedButRootUsedAlready", logs: logs, sub: sub}, nil
}

// WatchSuperDestinationExecutorReceivedButRootUsedAlready is a free log subscription operation binding the contract event 0xc85a4c9cf6ceb3da81d38c466e43c8b89a7f2857440772a73d2189d718b57841.
//
// Solidity: event SuperDestinationExecutorReceivedButRootUsedAlready(address indexed account, bytes32 indexed root)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorFilterer) WatchSuperDestinationExecutorReceivedButRootUsedAlready(opts *bind.WatchOpts, sink chan<- *SuperMockDestinationExecutorSuperDestinationExecutorReceivedButRootUsedAlready, account []common.Address, root [][32]byte) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var rootRule []interface{}
	for _, rootItem := range root {
		rootRule = append(rootRule, rootItem)
	}

	logs, sub, err := _SuperMockDestinationExecutor.contract.WatchLogs(opts, "SuperDestinationExecutorReceivedButRootUsedAlready", accountRule, rootRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperMockDestinationExecutorSuperDestinationExecutorReceivedButRootUsedAlready)
				if err := _SuperMockDestinationExecutor.contract.UnpackLog(event, "SuperDestinationExecutorReceivedButRootUsedAlready", log); err != nil {
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

// ParseSuperDestinationExecutorReceivedButRootUsedAlready is a log parse operation binding the contract event 0xc85a4c9cf6ceb3da81d38c466e43c8b89a7f2857440772a73d2189d718b57841.
//
// Solidity: event SuperDestinationExecutorReceivedButRootUsedAlready(address indexed account, bytes32 indexed root)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorFilterer) ParseSuperDestinationExecutorReceivedButRootUsedAlready(log types.Log) (*SuperMockDestinationExecutorSuperDestinationExecutorReceivedButRootUsedAlready, error) {
	event := new(SuperMockDestinationExecutorSuperDestinationExecutorReceivedButRootUsedAlready)
	if err := _SuperMockDestinationExecutor.contract.UnpackLog(event, "SuperDestinationExecutorReceivedButRootUsedAlready", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperMockDestinationExecutorSuperPositionMintRequestedIterator is returned from FilterSuperPositionMintRequested and is used to iterate over the raw logs and unpacked data for SuperPositionMintRequested events raised by the SuperMockDestinationExecutor contract.
type SuperMockDestinationExecutorSuperPositionMintRequestedIterator struct {
	Event *SuperMockDestinationExecutorSuperPositionMintRequested // Event containing the contract specifics and raw log

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
func (it *SuperMockDestinationExecutorSuperPositionMintRequestedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperMockDestinationExecutorSuperPositionMintRequested)
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
		it.Event = new(SuperMockDestinationExecutorSuperPositionMintRequested)
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
func (it *SuperMockDestinationExecutorSuperPositionMintRequestedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperMockDestinationExecutorSuperPositionMintRequestedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperMockDestinationExecutorSuperPositionMintRequested represents a SuperPositionMintRequested event raised by the SuperMockDestinationExecutor contract.
type SuperMockDestinationExecutorSuperPositionMintRequested struct {
	Account    common.Address
	SpToken    common.Address
	Amount     *big.Int
	DstChainId *big.Int
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterSuperPositionMintRequested is a free log retrieval operation binding the contract event 0x7ec946bedac80f139c7c4149ac44127f938a0ab50229c59b7c0cd5debc72c233.
//
// Solidity: event SuperPositionMintRequested(address indexed account, address indexed spToken, uint256 amount, uint256 indexed dstChainId)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorFilterer) FilterSuperPositionMintRequested(opts *bind.FilterOpts, account []common.Address, spToken []common.Address, dstChainId []*big.Int) (*SuperMockDestinationExecutorSuperPositionMintRequestedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var spTokenRule []interface{}
	for _, spTokenItem := range spToken {
		spTokenRule = append(spTokenRule, spTokenItem)
	}

	var dstChainIdRule []interface{}
	for _, dstChainIdItem := range dstChainId {
		dstChainIdRule = append(dstChainIdRule, dstChainIdItem)
	}

	logs, sub, err := _SuperMockDestinationExecutor.contract.FilterLogs(opts, "SuperPositionMintRequested", accountRule, spTokenRule, dstChainIdRule)
	if err != nil {
		return nil, err
	}
	return &SuperMockDestinationExecutorSuperPositionMintRequestedIterator{contract: _SuperMockDestinationExecutor.contract, event: "SuperPositionMintRequested", logs: logs, sub: sub}, nil
}

// WatchSuperPositionMintRequested is a free log subscription operation binding the contract event 0x7ec946bedac80f139c7c4149ac44127f938a0ab50229c59b7c0cd5debc72c233.
//
// Solidity: event SuperPositionMintRequested(address indexed account, address indexed spToken, uint256 amount, uint256 indexed dstChainId)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorFilterer) WatchSuperPositionMintRequested(opts *bind.WatchOpts, sink chan<- *SuperMockDestinationExecutorSuperPositionMintRequested, account []common.Address, spToken []common.Address, dstChainId []*big.Int) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var spTokenRule []interface{}
	for _, spTokenItem := range spToken {
		spTokenRule = append(spTokenRule, spTokenItem)
	}

	var dstChainIdRule []interface{}
	for _, dstChainIdItem := range dstChainId {
		dstChainIdRule = append(dstChainIdRule, dstChainIdItem)
	}

	logs, sub, err := _SuperMockDestinationExecutor.contract.WatchLogs(opts, "SuperPositionMintRequested", accountRule, spTokenRule, dstChainIdRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperMockDestinationExecutorSuperPositionMintRequested)
				if err := _SuperMockDestinationExecutor.contract.UnpackLog(event, "SuperPositionMintRequested", log); err != nil {
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

// ParseSuperPositionMintRequested is a log parse operation binding the contract event 0x7ec946bedac80f139c7c4149ac44127f938a0ab50229c59b7c0cd5debc72c233.
//
// Solidity: event SuperPositionMintRequested(address indexed account, address indexed spToken, uint256 amount, uint256 indexed dstChainId)
func (_SuperMockDestinationExecutor *SuperMockDestinationExecutorFilterer) ParseSuperPositionMintRequested(log types.Log) (*SuperMockDestinationExecutorSuperPositionMintRequested, error) {
	event := new(SuperMockDestinationExecutorSuperPositionMintRequested)
	if err := _SuperMockDestinationExecutor.contract.UnpackLog(event, "SuperPositionMintRequested", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
