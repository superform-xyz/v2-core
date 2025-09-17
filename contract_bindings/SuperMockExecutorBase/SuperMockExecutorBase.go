// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperMockExecutorBase

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

// SuperMockExecutorBaseMetaData contains all meta data concerning the SuperMockExecutorBase contract.
var SuperMockExecutorBaseMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"execute\",\"inputs\":[{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isInitialized\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isModuleType\",\"inputs\":[{\"name\":\"typeId\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"ledgerConfiguration\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"name\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"onInstall\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"onUninstall\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"validateHookCompliance\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"prevHook\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"hookData\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple[]\",\"internalType\":\"structExecution[]\",\"components\":[{\"name\":\"target\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"callData\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"version\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"SuperPositionMintRequested\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"spToken\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"dstChainId\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ALREADY_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FEE_NOT_TRANSFERRED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_BALANCE_FOR_FEE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_CALLER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_CHAIN_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_FEE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_YIELD_SOURCE_ORACLE_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MALICIOUS_HOOK_DETECTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MANAGER_NOT_SET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ModuleAlreadyInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"NOT_AUTHORIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_HOOKS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"ReentrancyGuardReentrantCall\",\"inputs\":[]}]",
}

// SuperMockExecutorBaseABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperMockExecutorBaseMetaData.ABI instead.
var SuperMockExecutorBaseABI = SuperMockExecutorBaseMetaData.ABI

// SuperMockExecutorBase is an auto generated Go binding around an Ethereum contract.
type SuperMockExecutorBase struct {
	SuperMockExecutorBaseCaller     // Read-only binding to the contract
	SuperMockExecutorBaseTransactor // Write-only binding to the contract
	SuperMockExecutorBaseFilterer   // Log filterer for contract events
}

// SuperMockExecutorBaseCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperMockExecutorBaseCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperMockExecutorBaseTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperMockExecutorBaseTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperMockExecutorBaseFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperMockExecutorBaseFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperMockExecutorBaseSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperMockExecutorBaseSession struct {
	Contract     *SuperMockExecutorBase // Generic contract binding to set the session for
	CallOpts     bind.CallOpts          // Call options to use throughout this session
	TransactOpts bind.TransactOpts      // Transaction auth options to use throughout this session
}

// SuperMockExecutorBaseCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperMockExecutorBaseCallerSession struct {
	Contract *SuperMockExecutorBaseCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                // Call options to use throughout this session
}

// SuperMockExecutorBaseTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperMockExecutorBaseTransactorSession struct {
	Contract     *SuperMockExecutorBaseTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                // Transaction auth options to use throughout this session
}

// SuperMockExecutorBaseRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperMockExecutorBaseRaw struct {
	Contract *SuperMockExecutorBase // Generic contract binding to access the raw methods on
}

// SuperMockExecutorBaseCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperMockExecutorBaseCallerRaw struct {
	Contract *SuperMockExecutorBaseCaller // Generic read-only contract binding to access the raw methods on
}

// SuperMockExecutorBaseTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperMockExecutorBaseTransactorRaw struct {
	Contract *SuperMockExecutorBaseTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperMockExecutorBase creates a new instance of SuperMockExecutorBase, bound to a specific deployed contract.
func NewSuperMockExecutorBase(address common.Address, backend bind.ContractBackend) (*SuperMockExecutorBase, error) {
	contract, err := bindSuperMockExecutorBase(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperMockExecutorBase{SuperMockExecutorBaseCaller: SuperMockExecutorBaseCaller{contract: contract}, SuperMockExecutorBaseTransactor: SuperMockExecutorBaseTransactor{contract: contract}, SuperMockExecutorBaseFilterer: SuperMockExecutorBaseFilterer{contract: contract}}, nil
}

// NewSuperMockExecutorBaseCaller creates a new read-only instance of SuperMockExecutorBase, bound to a specific deployed contract.
func NewSuperMockExecutorBaseCaller(address common.Address, caller bind.ContractCaller) (*SuperMockExecutorBaseCaller, error) {
	contract, err := bindSuperMockExecutorBase(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperMockExecutorBaseCaller{contract: contract}, nil
}

// NewSuperMockExecutorBaseTransactor creates a new write-only instance of SuperMockExecutorBase, bound to a specific deployed contract.
func NewSuperMockExecutorBaseTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperMockExecutorBaseTransactor, error) {
	contract, err := bindSuperMockExecutorBase(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperMockExecutorBaseTransactor{contract: contract}, nil
}

// NewSuperMockExecutorBaseFilterer creates a new log filterer instance of SuperMockExecutorBase, bound to a specific deployed contract.
func NewSuperMockExecutorBaseFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperMockExecutorBaseFilterer, error) {
	contract, err := bindSuperMockExecutorBase(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperMockExecutorBaseFilterer{contract: contract}, nil
}

// bindSuperMockExecutorBase binds a generic wrapper to an already deployed contract.
func bindSuperMockExecutorBase(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperMockExecutorBaseMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperMockExecutorBase *SuperMockExecutorBaseRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperMockExecutorBase.Contract.SuperMockExecutorBaseCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperMockExecutorBase *SuperMockExecutorBaseRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperMockExecutorBase.Contract.SuperMockExecutorBaseTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperMockExecutorBase *SuperMockExecutorBaseRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperMockExecutorBase.Contract.SuperMockExecutorBaseTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperMockExecutorBase *SuperMockExecutorBaseCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperMockExecutorBase.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperMockExecutorBase *SuperMockExecutorBaseTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperMockExecutorBase.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperMockExecutorBase *SuperMockExecutorBaseTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperMockExecutorBase.Contract.contract.Transact(opts, method, params...)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperMockExecutorBase *SuperMockExecutorBaseCaller) IsInitialized(opts *bind.CallOpts, account common.Address) (bool, error) {
	var out []interface{}
	err := _SuperMockExecutorBase.contract.Call(opts, &out, "isInitialized", account)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperMockExecutorBase *SuperMockExecutorBaseSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperMockExecutorBase.Contract.IsInitialized(&_SuperMockExecutorBase.CallOpts, account)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperMockExecutorBase *SuperMockExecutorBaseCallerSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperMockExecutorBase.Contract.IsInitialized(&_SuperMockExecutorBase.CallOpts, account)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeId) pure returns(bool)
func (_SuperMockExecutorBase *SuperMockExecutorBaseCaller) IsModuleType(opts *bind.CallOpts, typeId *big.Int) (bool, error) {
	var out []interface{}
	err := _SuperMockExecutorBase.contract.Call(opts, &out, "isModuleType", typeId)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeId) pure returns(bool)
func (_SuperMockExecutorBase *SuperMockExecutorBaseSession) IsModuleType(typeId *big.Int) (bool, error) {
	return _SuperMockExecutorBase.Contract.IsModuleType(&_SuperMockExecutorBase.CallOpts, typeId)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeId) pure returns(bool)
func (_SuperMockExecutorBase *SuperMockExecutorBaseCallerSession) IsModuleType(typeId *big.Int) (bool, error) {
	return _SuperMockExecutorBase.Contract.IsModuleType(&_SuperMockExecutorBase.CallOpts, typeId)
}

// LedgerConfiguration is a free data retrieval call binding the contract method 0x6740419b.
//
// Solidity: function ledgerConfiguration() view returns(address)
func (_SuperMockExecutorBase *SuperMockExecutorBaseCaller) LedgerConfiguration(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperMockExecutorBase.contract.Call(opts, &out, "ledgerConfiguration")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// LedgerConfiguration is a free data retrieval call binding the contract method 0x6740419b.
//
// Solidity: function ledgerConfiguration() view returns(address)
func (_SuperMockExecutorBase *SuperMockExecutorBaseSession) LedgerConfiguration() (common.Address, error) {
	return _SuperMockExecutorBase.Contract.LedgerConfiguration(&_SuperMockExecutorBase.CallOpts)
}

// LedgerConfiguration is a free data retrieval call binding the contract method 0x6740419b.
//
// Solidity: function ledgerConfiguration() view returns(address)
func (_SuperMockExecutorBase *SuperMockExecutorBaseCallerSession) LedgerConfiguration() (common.Address, error) {
	return _SuperMockExecutorBase.Contract.LedgerConfiguration(&_SuperMockExecutorBase.CallOpts)
}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() view returns(string)
func (_SuperMockExecutorBase *SuperMockExecutorBaseCaller) Name(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperMockExecutorBase.contract.Call(opts, &out, "name")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() view returns(string)
func (_SuperMockExecutorBase *SuperMockExecutorBaseSession) Name() (string, error) {
	return _SuperMockExecutorBase.Contract.Name(&_SuperMockExecutorBase.CallOpts)
}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() view returns(string)
func (_SuperMockExecutorBase *SuperMockExecutorBaseCallerSession) Name() (string, error) {
	return _SuperMockExecutorBase.Contract.Name(&_SuperMockExecutorBase.CallOpts)
}

// ValidateHookCompliance is a free data retrieval call binding the contract method 0x4a03fda4.
//
// Solidity: function validateHookCompliance(address hook, address prevHook, address account, bytes hookData) view returns((address,uint256,bytes)[])
func (_SuperMockExecutorBase *SuperMockExecutorBaseCaller) ValidateHookCompliance(opts *bind.CallOpts, hook common.Address, prevHook common.Address, account common.Address, hookData []byte) ([]Execution, error) {
	var out []interface{}
	err := _SuperMockExecutorBase.contract.Call(opts, &out, "validateHookCompliance", hook, prevHook, account, hookData)

	if err != nil {
		return *new([]Execution), err
	}

	out0 := *abi.ConvertType(out[0], new([]Execution)).(*[]Execution)

	return out0, err

}

// ValidateHookCompliance is a free data retrieval call binding the contract method 0x4a03fda4.
//
// Solidity: function validateHookCompliance(address hook, address prevHook, address account, bytes hookData) view returns((address,uint256,bytes)[])
func (_SuperMockExecutorBase *SuperMockExecutorBaseSession) ValidateHookCompliance(hook common.Address, prevHook common.Address, account common.Address, hookData []byte) ([]Execution, error) {
	return _SuperMockExecutorBase.Contract.ValidateHookCompliance(&_SuperMockExecutorBase.CallOpts, hook, prevHook, account, hookData)
}

// ValidateHookCompliance is a free data retrieval call binding the contract method 0x4a03fda4.
//
// Solidity: function validateHookCompliance(address hook, address prevHook, address account, bytes hookData) view returns((address,uint256,bytes)[])
func (_SuperMockExecutorBase *SuperMockExecutorBaseCallerSession) ValidateHookCompliance(hook common.Address, prevHook common.Address, account common.Address, hookData []byte) ([]Execution, error) {
	return _SuperMockExecutorBase.Contract.ValidateHookCompliance(&_SuperMockExecutorBase.CallOpts, hook, prevHook, account, hookData)
}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() view returns(string)
func (_SuperMockExecutorBase *SuperMockExecutorBaseCaller) Version(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperMockExecutorBase.contract.Call(opts, &out, "version")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() view returns(string)
func (_SuperMockExecutorBase *SuperMockExecutorBaseSession) Version() (string, error) {
	return _SuperMockExecutorBase.Contract.Version(&_SuperMockExecutorBase.CallOpts)
}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() view returns(string)
func (_SuperMockExecutorBase *SuperMockExecutorBaseCallerSession) Version() (string, error) {
	return _SuperMockExecutorBase.Contract.Version(&_SuperMockExecutorBase.CallOpts)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_SuperMockExecutorBase *SuperMockExecutorBaseTransactor) Execute(opts *bind.TransactOpts, data []byte) (*types.Transaction, error) {
	return _SuperMockExecutorBase.contract.Transact(opts, "execute", data)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_SuperMockExecutorBase *SuperMockExecutorBaseSession) Execute(data []byte) (*types.Transaction, error) {
	return _SuperMockExecutorBase.Contract.Execute(&_SuperMockExecutorBase.TransactOpts, data)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_SuperMockExecutorBase *SuperMockExecutorBaseTransactorSession) Execute(data []byte) (*types.Transaction, error) {
	return _SuperMockExecutorBase.Contract.Execute(&_SuperMockExecutorBase.TransactOpts, data)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_SuperMockExecutorBase *SuperMockExecutorBaseTransactor) OnInstall(opts *bind.TransactOpts, arg0 []byte) (*types.Transaction, error) {
	return _SuperMockExecutorBase.contract.Transact(opts, "onInstall", arg0)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_SuperMockExecutorBase *SuperMockExecutorBaseSession) OnInstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperMockExecutorBase.Contract.OnInstall(&_SuperMockExecutorBase.TransactOpts, arg0)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_SuperMockExecutorBase *SuperMockExecutorBaseTransactorSession) OnInstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperMockExecutorBase.Contract.OnInstall(&_SuperMockExecutorBase.TransactOpts, arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperMockExecutorBase *SuperMockExecutorBaseTransactor) OnUninstall(opts *bind.TransactOpts, arg0 []byte) (*types.Transaction, error) {
	return _SuperMockExecutorBase.contract.Transact(opts, "onUninstall", arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperMockExecutorBase *SuperMockExecutorBaseSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperMockExecutorBase.Contract.OnUninstall(&_SuperMockExecutorBase.TransactOpts, arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperMockExecutorBase *SuperMockExecutorBaseTransactorSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperMockExecutorBase.Contract.OnUninstall(&_SuperMockExecutorBase.TransactOpts, arg0)
}

// SuperMockExecutorBaseSuperPositionMintRequestedIterator is returned from FilterSuperPositionMintRequested and is used to iterate over the raw logs and unpacked data for SuperPositionMintRequested events raised by the SuperMockExecutorBase contract.
type SuperMockExecutorBaseSuperPositionMintRequestedIterator struct {
	Event *SuperMockExecutorBaseSuperPositionMintRequested // Event containing the contract specifics and raw log

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
func (it *SuperMockExecutorBaseSuperPositionMintRequestedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperMockExecutorBaseSuperPositionMintRequested)
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
		it.Event = new(SuperMockExecutorBaseSuperPositionMintRequested)
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
func (it *SuperMockExecutorBaseSuperPositionMintRequestedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperMockExecutorBaseSuperPositionMintRequestedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperMockExecutorBaseSuperPositionMintRequested represents a SuperPositionMintRequested event raised by the SuperMockExecutorBase contract.
type SuperMockExecutorBaseSuperPositionMintRequested struct {
	Account    common.Address
	SpToken    common.Address
	Amount     *big.Int
	DstChainId *big.Int
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterSuperPositionMintRequested is a free log retrieval operation binding the contract event 0x7ec946bedac80f139c7c4149ac44127f938a0ab50229c59b7c0cd5debc72c233.
//
// Solidity: event SuperPositionMintRequested(address indexed account, address indexed spToken, uint256 amount, uint256 indexed dstChainId)
func (_SuperMockExecutorBase *SuperMockExecutorBaseFilterer) FilterSuperPositionMintRequested(opts *bind.FilterOpts, account []common.Address, spToken []common.Address, dstChainId []*big.Int) (*SuperMockExecutorBaseSuperPositionMintRequestedIterator, error) {

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

	logs, sub, err := _SuperMockExecutorBase.contract.FilterLogs(opts, "SuperPositionMintRequested", accountRule, spTokenRule, dstChainIdRule)
	if err != nil {
		return nil, err
	}
	return &SuperMockExecutorBaseSuperPositionMintRequestedIterator{contract: _SuperMockExecutorBase.contract, event: "SuperPositionMintRequested", logs: logs, sub: sub}, nil
}

// WatchSuperPositionMintRequested is a free log subscription operation binding the contract event 0x7ec946bedac80f139c7c4149ac44127f938a0ab50229c59b7c0cd5debc72c233.
//
// Solidity: event SuperPositionMintRequested(address indexed account, address indexed spToken, uint256 amount, uint256 indexed dstChainId)
func (_SuperMockExecutorBase *SuperMockExecutorBaseFilterer) WatchSuperPositionMintRequested(opts *bind.WatchOpts, sink chan<- *SuperMockExecutorBaseSuperPositionMintRequested, account []common.Address, spToken []common.Address, dstChainId []*big.Int) (event.Subscription, error) {

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

	logs, sub, err := _SuperMockExecutorBase.contract.WatchLogs(opts, "SuperPositionMintRequested", accountRule, spTokenRule, dstChainIdRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperMockExecutorBaseSuperPositionMintRequested)
				if err := _SuperMockExecutorBase.contract.UnpackLog(event, "SuperPositionMintRequested", log); err != nil {
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
func (_SuperMockExecutorBase *SuperMockExecutorBaseFilterer) ParseSuperPositionMintRequested(log types.Log) (*SuperMockExecutorBaseSuperPositionMintRequested, error) {
	event := new(SuperMockExecutorBaseSuperPositionMintRequested)
	if err := _SuperMockExecutorBase.contract.UnpackLog(event, "SuperPositionMintRequested", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
