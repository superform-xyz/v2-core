// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperExecutorBaseSimulations

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

// SuperExecutorBaseSimulationsMetaData contains all meta data concerning the SuperExecutorBaseSimulations contract.
var SuperExecutorBaseSimulationsMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"execute\",\"inputs\":[{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isInitialized\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isModuleType\",\"inputs\":[{\"name\":\"typeId\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"ledgerConfiguration\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"name\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"onInstall\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"onUninstall\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"validateHookCompliance\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"prevHook\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"hookData\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple[]\",\"internalType\":\"structExecution[]\",\"components\":[{\"name\":\"target\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"callData\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"version\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"SuperPositionMintRequested\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"spToken\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"dstChainId\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ALREADY_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FEE_NOT_TRANSFERRED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_BALANCE_FOR_FEE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_CALLER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_CHAIN_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_FEE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_YIELD_SOURCE_ORACLE_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MALICIOUS_HOOK_DETECTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MANAGER_NOT_SET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ModuleAlreadyInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"NOT_AUTHORIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_HOOKS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"ReentrancyGuardReentrantCall\",\"inputs\":[]}]",
}

// SuperExecutorBaseSimulationsABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperExecutorBaseSimulationsMetaData.ABI instead.
var SuperExecutorBaseSimulationsABI = SuperExecutorBaseSimulationsMetaData.ABI

// SuperExecutorBaseSimulations is an auto generated Go binding around an Ethereum contract.
type SuperExecutorBaseSimulations struct {
	SuperExecutorBaseSimulationsCaller     // Read-only binding to the contract
	SuperExecutorBaseSimulationsTransactor // Write-only binding to the contract
	SuperExecutorBaseSimulationsFilterer   // Log filterer for contract events
}

// SuperExecutorBaseSimulationsCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperExecutorBaseSimulationsCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperExecutorBaseSimulationsTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperExecutorBaseSimulationsTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperExecutorBaseSimulationsFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperExecutorBaseSimulationsFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperExecutorBaseSimulationsSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperExecutorBaseSimulationsSession struct {
	Contract     *SuperExecutorBaseSimulations // Generic contract binding to set the session for
	CallOpts     bind.CallOpts                 // Call options to use throughout this session
	TransactOpts bind.TransactOpts             // Transaction auth options to use throughout this session
}

// SuperExecutorBaseSimulationsCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperExecutorBaseSimulationsCallerSession struct {
	Contract *SuperExecutorBaseSimulationsCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                       // Call options to use throughout this session
}

// SuperExecutorBaseSimulationsTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperExecutorBaseSimulationsTransactorSession struct {
	Contract     *SuperExecutorBaseSimulationsTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                       // Transaction auth options to use throughout this session
}

// SuperExecutorBaseSimulationsRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperExecutorBaseSimulationsRaw struct {
	Contract *SuperExecutorBaseSimulations // Generic contract binding to access the raw methods on
}

// SuperExecutorBaseSimulationsCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperExecutorBaseSimulationsCallerRaw struct {
	Contract *SuperExecutorBaseSimulationsCaller // Generic read-only contract binding to access the raw methods on
}

// SuperExecutorBaseSimulationsTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperExecutorBaseSimulationsTransactorRaw struct {
	Contract *SuperExecutorBaseSimulationsTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperExecutorBaseSimulations creates a new instance of SuperExecutorBaseSimulations, bound to a specific deployed contract.
func NewSuperExecutorBaseSimulations(address common.Address, backend bind.ContractBackend) (*SuperExecutorBaseSimulations, error) {
	contract, err := bindSuperExecutorBaseSimulations(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperExecutorBaseSimulations{SuperExecutorBaseSimulationsCaller: SuperExecutorBaseSimulationsCaller{contract: contract}, SuperExecutorBaseSimulationsTransactor: SuperExecutorBaseSimulationsTransactor{contract: contract}, SuperExecutorBaseSimulationsFilterer: SuperExecutorBaseSimulationsFilterer{contract: contract}}, nil
}

// NewSuperExecutorBaseSimulationsCaller creates a new read-only instance of SuperExecutorBaseSimulations, bound to a specific deployed contract.
func NewSuperExecutorBaseSimulationsCaller(address common.Address, caller bind.ContractCaller) (*SuperExecutorBaseSimulationsCaller, error) {
	contract, err := bindSuperExecutorBaseSimulations(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperExecutorBaseSimulationsCaller{contract: contract}, nil
}

// NewSuperExecutorBaseSimulationsTransactor creates a new write-only instance of SuperExecutorBaseSimulations, bound to a specific deployed contract.
func NewSuperExecutorBaseSimulationsTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperExecutorBaseSimulationsTransactor, error) {
	contract, err := bindSuperExecutorBaseSimulations(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperExecutorBaseSimulationsTransactor{contract: contract}, nil
}

// NewSuperExecutorBaseSimulationsFilterer creates a new log filterer instance of SuperExecutorBaseSimulations, bound to a specific deployed contract.
func NewSuperExecutorBaseSimulationsFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperExecutorBaseSimulationsFilterer, error) {
	contract, err := bindSuperExecutorBaseSimulations(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperExecutorBaseSimulationsFilterer{contract: contract}, nil
}

// bindSuperExecutorBaseSimulations binds a generic wrapper to an already deployed contract.
func bindSuperExecutorBaseSimulations(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperExecutorBaseSimulationsMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperExecutorBaseSimulations.Contract.SuperExecutorBaseSimulationsCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperExecutorBaseSimulations.Contract.SuperExecutorBaseSimulationsTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperExecutorBaseSimulations.Contract.SuperExecutorBaseSimulationsTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperExecutorBaseSimulations.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperExecutorBaseSimulations.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperExecutorBaseSimulations.Contract.contract.Transact(opts, method, params...)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsCaller) IsInitialized(opts *bind.CallOpts, account common.Address) (bool, error) {
	var out []interface{}
	err := _SuperExecutorBaseSimulations.contract.Call(opts, &out, "isInitialized", account)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperExecutorBaseSimulations.Contract.IsInitialized(&_SuperExecutorBaseSimulations.CallOpts, account)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsCallerSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperExecutorBaseSimulations.Contract.IsInitialized(&_SuperExecutorBaseSimulations.CallOpts, account)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeId) pure returns(bool)
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsCaller) IsModuleType(opts *bind.CallOpts, typeId *big.Int) (bool, error) {
	var out []interface{}
	err := _SuperExecutorBaseSimulations.contract.Call(opts, &out, "isModuleType", typeId)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeId) pure returns(bool)
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsSession) IsModuleType(typeId *big.Int) (bool, error) {
	return _SuperExecutorBaseSimulations.Contract.IsModuleType(&_SuperExecutorBaseSimulations.CallOpts, typeId)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeId) pure returns(bool)
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsCallerSession) IsModuleType(typeId *big.Int) (bool, error) {
	return _SuperExecutorBaseSimulations.Contract.IsModuleType(&_SuperExecutorBaseSimulations.CallOpts, typeId)
}

// LedgerConfiguration is a free data retrieval call binding the contract method 0x6740419b.
//
// Solidity: function ledgerConfiguration() view returns(address)
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsCaller) LedgerConfiguration(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperExecutorBaseSimulations.contract.Call(opts, &out, "ledgerConfiguration")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// LedgerConfiguration is a free data retrieval call binding the contract method 0x6740419b.
//
// Solidity: function ledgerConfiguration() view returns(address)
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsSession) LedgerConfiguration() (common.Address, error) {
	return _SuperExecutorBaseSimulations.Contract.LedgerConfiguration(&_SuperExecutorBaseSimulations.CallOpts)
}

// LedgerConfiguration is a free data retrieval call binding the contract method 0x6740419b.
//
// Solidity: function ledgerConfiguration() view returns(address)
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsCallerSession) LedgerConfiguration() (common.Address, error) {
	return _SuperExecutorBaseSimulations.Contract.LedgerConfiguration(&_SuperExecutorBaseSimulations.CallOpts)
}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() view returns(string)
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsCaller) Name(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperExecutorBaseSimulations.contract.Call(opts, &out, "name")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() view returns(string)
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsSession) Name() (string, error) {
	return _SuperExecutorBaseSimulations.Contract.Name(&_SuperExecutorBaseSimulations.CallOpts)
}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() view returns(string)
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsCallerSession) Name() (string, error) {
	return _SuperExecutorBaseSimulations.Contract.Name(&_SuperExecutorBaseSimulations.CallOpts)
}

// ValidateHookCompliance is a free data retrieval call binding the contract method 0x4a03fda4.
//
// Solidity: function validateHookCompliance(address hook, address prevHook, address account, bytes hookData) view returns((address,uint256,bytes)[])
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsCaller) ValidateHookCompliance(opts *bind.CallOpts, hook common.Address, prevHook common.Address, account common.Address, hookData []byte) ([]Execution, error) {
	var out []interface{}
	err := _SuperExecutorBaseSimulations.contract.Call(opts, &out, "validateHookCompliance", hook, prevHook, account, hookData)

	if err != nil {
		return *new([]Execution), err
	}

	out0 := *abi.ConvertType(out[0], new([]Execution)).(*[]Execution)

	return out0, err

}

// ValidateHookCompliance is a free data retrieval call binding the contract method 0x4a03fda4.
//
// Solidity: function validateHookCompliance(address hook, address prevHook, address account, bytes hookData) view returns((address,uint256,bytes)[])
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsSession) ValidateHookCompliance(hook common.Address, prevHook common.Address, account common.Address, hookData []byte) ([]Execution, error) {
	return _SuperExecutorBaseSimulations.Contract.ValidateHookCompliance(&_SuperExecutorBaseSimulations.CallOpts, hook, prevHook, account, hookData)
}

// ValidateHookCompliance is a free data retrieval call binding the contract method 0x4a03fda4.
//
// Solidity: function validateHookCompliance(address hook, address prevHook, address account, bytes hookData) view returns((address,uint256,bytes)[])
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsCallerSession) ValidateHookCompliance(hook common.Address, prevHook common.Address, account common.Address, hookData []byte) ([]Execution, error) {
	return _SuperExecutorBaseSimulations.Contract.ValidateHookCompliance(&_SuperExecutorBaseSimulations.CallOpts, hook, prevHook, account, hookData)
}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() view returns(string)
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsCaller) Version(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperExecutorBaseSimulations.contract.Call(opts, &out, "version")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() view returns(string)
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsSession) Version() (string, error) {
	return _SuperExecutorBaseSimulations.Contract.Version(&_SuperExecutorBaseSimulations.CallOpts)
}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() view returns(string)
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsCallerSession) Version() (string, error) {
	return _SuperExecutorBaseSimulations.Contract.Version(&_SuperExecutorBaseSimulations.CallOpts)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsTransactor) Execute(opts *bind.TransactOpts, data []byte) (*types.Transaction, error) {
	return _SuperExecutorBaseSimulations.contract.Transact(opts, "execute", data)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsSession) Execute(data []byte) (*types.Transaction, error) {
	return _SuperExecutorBaseSimulations.Contract.Execute(&_SuperExecutorBaseSimulations.TransactOpts, data)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsTransactorSession) Execute(data []byte) (*types.Transaction, error) {
	return _SuperExecutorBaseSimulations.Contract.Execute(&_SuperExecutorBaseSimulations.TransactOpts, data)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsTransactor) OnInstall(opts *bind.TransactOpts, arg0 []byte) (*types.Transaction, error) {
	return _SuperExecutorBaseSimulations.contract.Transact(opts, "onInstall", arg0)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsSession) OnInstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperExecutorBaseSimulations.Contract.OnInstall(&_SuperExecutorBaseSimulations.TransactOpts, arg0)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsTransactorSession) OnInstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperExecutorBaseSimulations.Contract.OnInstall(&_SuperExecutorBaseSimulations.TransactOpts, arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsTransactor) OnUninstall(opts *bind.TransactOpts, arg0 []byte) (*types.Transaction, error) {
	return _SuperExecutorBaseSimulations.contract.Transact(opts, "onUninstall", arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperExecutorBaseSimulations.Contract.OnUninstall(&_SuperExecutorBaseSimulations.TransactOpts, arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsTransactorSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperExecutorBaseSimulations.Contract.OnUninstall(&_SuperExecutorBaseSimulations.TransactOpts, arg0)
}

// SuperExecutorBaseSimulationsSuperPositionMintRequestedIterator is returned from FilterSuperPositionMintRequested and is used to iterate over the raw logs and unpacked data for SuperPositionMintRequested events raised by the SuperExecutorBaseSimulations contract.
type SuperExecutorBaseSimulationsSuperPositionMintRequestedIterator struct {
	Event *SuperExecutorBaseSimulationsSuperPositionMintRequested // Event containing the contract specifics and raw log

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
func (it *SuperExecutorBaseSimulationsSuperPositionMintRequestedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperExecutorBaseSimulationsSuperPositionMintRequested)
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
		it.Event = new(SuperExecutorBaseSimulationsSuperPositionMintRequested)
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
func (it *SuperExecutorBaseSimulationsSuperPositionMintRequestedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperExecutorBaseSimulationsSuperPositionMintRequestedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperExecutorBaseSimulationsSuperPositionMintRequested represents a SuperPositionMintRequested event raised by the SuperExecutorBaseSimulations contract.
type SuperExecutorBaseSimulationsSuperPositionMintRequested struct {
	Account    common.Address
	SpToken    common.Address
	Amount     *big.Int
	DstChainId *big.Int
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterSuperPositionMintRequested is a free log retrieval operation binding the contract event 0x7ec946bedac80f139c7c4149ac44127f938a0ab50229c59b7c0cd5debc72c233.
//
// Solidity: event SuperPositionMintRequested(address indexed account, address indexed spToken, uint256 amount, uint256 indexed dstChainId)
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsFilterer) FilterSuperPositionMintRequested(opts *bind.FilterOpts, account []common.Address, spToken []common.Address, dstChainId []*big.Int) (*SuperExecutorBaseSimulationsSuperPositionMintRequestedIterator, error) {

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

	logs, sub, err := _SuperExecutorBaseSimulations.contract.FilterLogs(opts, "SuperPositionMintRequested", accountRule, spTokenRule, dstChainIdRule)
	if err != nil {
		return nil, err
	}
	return &SuperExecutorBaseSimulationsSuperPositionMintRequestedIterator{contract: _SuperExecutorBaseSimulations.contract, event: "SuperPositionMintRequested", logs: logs, sub: sub}, nil
}

// WatchSuperPositionMintRequested is a free log subscription operation binding the contract event 0x7ec946bedac80f139c7c4149ac44127f938a0ab50229c59b7c0cd5debc72c233.
//
// Solidity: event SuperPositionMintRequested(address indexed account, address indexed spToken, uint256 amount, uint256 indexed dstChainId)
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsFilterer) WatchSuperPositionMintRequested(opts *bind.WatchOpts, sink chan<- *SuperExecutorBaseSimulationsSuperPositionMintRequested, account []common.Address, spToken []common.Address, dstChainId []*big.Int) (event.Subscription, error) {

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

	logs, sub, err := _SuperExecutorBaseSimulations.contract.WatchLogs(opts, "SuperPositionMintRequested", accountRule, spTokenRule, dstChainIdRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperExecutorBaseSimulationsSuperPositionMintRequested)
				if err := _SuperExecutorBaseSimulations.contract.UnpackLog(event, "SuperPositionMintRequested", log); err != nil {
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
func (_SuperExecutorBaseSimulations *SuperExecutorBaseSimulationsFilterer) ParseSuperPositionMintRequested(log types.Log) (*SuperExecutorBaseSimulationsSuperPositionMintRequested, error) {
	event := new(SuperExecutorBaseSimulationsSuperPositionMintRequested)
	if err := _SuperExecutorBaseSimulations.contract.UnpackLog(event, "SuperPositionMintRequested", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
