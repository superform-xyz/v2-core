// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperExecutorBase

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

// SuperExecutorBaseMetaData contains all meta data concerning the SuperExecutorBase contract.
var SuperExecutorBaseMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"execute\",\"inputs\":[{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isInitialized\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isModuleType\",\"inputs\":[{\"name\":\"typeID\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"ledgerConfiguration\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperLedgerConfiguration\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"name\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"onInstall\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"onUninstall\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"validateHookCompliance\",\"inputs\":[{\"name\":\"hook\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"prevHook\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"hookData\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple[]\",\"internalType\":\"structExecution[]\",\"components\":[{\"name\":\"target\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"callData\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"version\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"SuperPositionMintRequested\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"spToken\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"dstChainId\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ALREADY_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FEE_NOT_TRANSFERRED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FIRST_HOOK_CANNOT_USE_PREVIOUS_AMOUNT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INSUFFICIENT_BALANCE_FOR_FEE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_CALLER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_CHAIN_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_FEE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_YIELD_SOURCE_ORACLE_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"LENGTH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MALICIOUS_HOOK_DETECTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MANAGER_NOT_SET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ModuleAlreadyInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"NOT_AUTHORIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_INITIALIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_HOOKS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotInitialized\",\"inputs\":[{\"name\":\"smartAccount\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"type\":\"error\",\"name\":\"ReentrancyGuardReentrantCall\",\"inputs\":[]}]",
}

// SuperExecutorBaseABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperExecutorBaseMetaData.ABI instead.
var SuperExecutorBaseABI = SuperExecutorBaseMetaData.ABI

// SuperExecutorBase is an auto generated Go binding around an Ethereum contract.
type SuperExecutorBase struct {
	SuperExecutorBaseCaller     // Read-only binding to the contract
	SuperExecutorBaseTransactor // Write-only binding to the contract
	SuperExecutorBaseFilterer   // Log filterer for contract events
}

// SuperExecutorBaseCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperExecutorBaseCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperExecutorBaseTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperExecutorBaseTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperExecutorBaseFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperExecutorBaseFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperExecutorBaseSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperExecutorBaseSession struct {
	Contract     *SuperExecutorBase // Generic contract binding to set the session for
	CallOpts     bind.CallOpts      // Call options to use throughout this session
	TransactOpts bind.TransactOpts  // Transaction auth options to use throughout this session
}

// SuperExecutorBaseCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperExecutorBaseCallerSession struct {
	Contract *SuperExecutorBaseCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts            // Call options to use throughout this session
}

// SuperExecutorBaseTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperExecutorBaseTransactorSession struct {
	Contract     *SuperExecutorBaseTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts            // Transaction auth options to use throughout this session
}

// SuperExecutorBaseRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperExecutorBaseRaw struct {
	Contract *SuperExecutorBase // Generic contract binding to access the raw methods on
}

// SuperExecutorBaseCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperExecutorBaseCallerRaw struct {
	Contract *SuperExecutorBaseCaller // Generic read-only contract binding to access the raw methods on
}

// SuperExecutorBaseTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperExecutorBaseTransactorRaw struct {
	Contract *SuperExecutorBaseTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperExecutorBase creates a new instance of SuperExecutorBase, bound to a specific deployed contract.
func NewSuperExecutorBase(address common.Address, backend bind.ContractBackend) (*SuperExecutorBase, error) {
	contract, err := bindSuperExecutorBase(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperExecutorBase{SuperExecutorBaseCaller: SuperExecutorBaseCaller{contract: contract}, SuperExecutorBaseTransactor: SuperExecutorBaseTransactor{contract: contract}, SuperExecutorBaseFilterer: SuperExecutorBaseFilterer{contract: contract}}, nil
}

// NewSuperExecutorBaseCaller creates a new read-only instance of SuperExecutorBase, bound to a specific deployed contract.
func NewSuperExecutorBaseCaller(address common.Address, caller bind.ContractCaller) (*SuperExecutorBaseCaller, error) {
	contract, err := bindSuperExecutorBase(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperExecutorBaseCaller{contract: contract}, nil
}

// NewSuperExecutorBaseTransactor creates a new write-only instance of SuperExecutorBase, bound to a specific deployed contract.
func NewSuperExecutorBaseTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperExecutorBaseTransactor, error) {
	contract, err := bindSuperExecutorBase(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperExecutorBaseTransactor{contract: contract}, nil
}

// NewSuperExecutorBaseFilterer creates a new log filterer instance of SuperExecutorBase, bound to a specific deployed contract.
func NewSuperExecutorBaseFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperExecutorBaseFilterer, error) {
	contract, err := bindSuperExecutorBase(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperExecutorBaseFilterer{contract: contract}, nil
}

// bindSuperExecutorBase binds a generic wrapper to an already deployed contract.
func bindSuperExecutorBase(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperExecutorBaseMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperExecutorBase *SuperExecutorBaseRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperExecutorBase.Contract.SuperExecutorBaseCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperExecutorBase *SuperExecutorBaseRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperExecutorBase.Contract.SuperExecutorBaseTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperExecutorBase *SuperExecutorBaseRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperExecutorBase.Contract.SuperExecutorBaseTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperExecutorBase *SuperExecutorBaseCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperExecutorBase.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperExecutorBase *SuperExecutorBaseTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperExecutorBase.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperExecutorBase *SuperExecutorBaseTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperExecutorBase.Contract.contract.Transact(opts, method, params...)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperExecutorBase *SuperExecutorBaseCaller) IsInitialized(opts *bind.CallOpts, account common.Address) (bool, error) {
	var out []interface{}
	err := _SuperExecutorBase.contract.Call(opts, &out, "isInitialized", account)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperExecutorBase *SuperExecutorBaseSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperExecutorBase.Contract.IsInitialized(&_SuperExecutorBase.CallOpts, account)
}

// IsInitialized is a free data retrieval call binding the contract method 0xd60b347f.
//
// Solidity: function isInitialized(address account) view returns(bool)
func (_SuperExecutorBase *SuperExecutorBaseCallerSession) IsInitialized(account common.Address) (bool, error) {
	return _SuperExecutorBase.Contract.IsInitialized(&_SuperExecutorBase.CallOpts, account)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeID) pure returns(bool)
func (_SuperExecutorBase *SuperExecutorBaseCaller) IsModuleType(opts *bind.CallOpts, typeID *big.Int) (bool, error) {
	var out []interface{}
	err := _SuperExecutorBase.contract.Call(opts, &out, "isModuleType", typeID)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeID) pure returns(bool)
func (_SuperExecutorBase *SuperExecutorBaseSession) IsModuleType(typeID *big.Int) (bool, error) {
	return _SuperExecutorBase.Contract.IsModuleType(&_SuperExecutorBase.CallOpts, typeID)
}

// IsModuleType is a free data retrieval call binding the contract method 0xecd05961.
//
// Solidity: function isModuleType(uint256 typeID) pure returns(bool)
func (_SuperExecutorBase *SuperExecutorBaseCallerSession) IsModuleType(typeID *big.Int) (bool, error) {
	return _SuperExecutorBase.Contract.IsModuleType(&_SuperExecutorBase.CallOpts, typeID)
}

// LedgerConfiguration is a free data retrieval call binding the contract method 0x6740419b.
//
// Solidity: function ledgerConfiguration() view returns(address)
func (_SuperExecutorBase *SuperExecutorBaseCaller) LedgerConfiguration(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperExecutorBase.contract.Call(opts, &out, "ledgerConfiguration")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// LedgerConfiguration is a free data retrieval call binding the contract method 0x6740419b.
//
// Solidity: function ledgerConfiguration() view returns(address)
func (_SuperExecutorBase *SuperExecutorBaseSession) LedgerConfiguration() (common.Address, error) {
	return _SuperExecutorBase.Contract.LedgerConfiguration(&_SuperExecutorBase.CallOpts)
}

// LedgerConfiguration is a free data retrieval call binding the contract method 0x6740419b.
//
// Solidity: function ledgerConfiguration() view returns(address)
func (_SuperExecutorBase *SuperExecutorBaseCallerSession) LedgerConfiguration() (common.Address, error) {
	return _SuperExecutorBase.Contract.LedgerConfiguration(&_SuperExecutorBase.CallOpts)
}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() view returns(string)
func (_SuperExecutorBase *SuperExecutorBaseCaller) Name(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperExecutorBase.contract.Call(opts, &out, "name")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() view returns(string)
func (_SuperExecutorBase *SuperExecutorBaseSession) Name() (string, error) {
	return _SuperExecutorBase.Contract.Name(&_SuperExecutorBase.CallOpts)
}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() view returns(string)
func (_SuperExecutorBase *SuperExecutorBaseCallerSession) Name() (string, error) {
	return _SuperExecutorBase.Contract.Name(&_SuperExecutorBase.CallOpts)
}

// ValidateHookCompliance is a free data retrieval call binding the contract method 0x4a03fda4.
//
// Solidity: function validateHookCompliance(address hook, address prevHook, address account, bytes hookData) view returns((address,uint256,bytes)[])
func (_SuperExecutorBase *SuperExecutorBaseCaller) ValidateHookCompliance(opts *bind.CallOpts, hook common.Address, prevHook common.Address, account common.Address, hookData []byte) ([]Execution, error) {
	var out []interface{}
	err := _SuperExecutorBase.contract.Call(opts, &out, "validateHookCompliance", hook, prevHook, account, hookData)

	if err != nil {
		return *new([]Execution), err
	}

	out0 := *abi.ConvertType(out[0], new([]Execution)).(*[]Execution)

	return out0, err

}

// ValidateHookCompliance is a free data retrieval call binding the contract method 0x4a03fda4.
//
// Solidity: function validateHookCompliance(address hook, address prevHook, address account, bytes hookData) view returns((address,uint256,bytes)[])
func (_SuperExecutorBase *SuperExecutorBaseSession) ValidateHookCompliance(hook common.Address, prevHook common.Address, account common.Address, hookData []byte) ([]Execution, error) {
	return _SuperExecutorBase.Contract.ValidateHookCompliance(&_SuperExecutorBase.CallOpts, hook, prevHook, account, hookData)
}

// ValidateHookCompliance is a free data retrieval call binding the contract method 0x4a03fda4.
//
// Solidity: function validateHookCompliance(address hook, address prevHook, address account, bytes hookData) view returns((address,uint256,bytes)[])
func (_SuperExecutorBase *SuperExecutorBaseCallerSession) ValidateHookCompliance(hook common.Address, prevHook common.Address, account common.Address, hookData []byte) ([]Execution, error) {
	return _SuperExecutorBase.Contract.ValidateHookCompliance(&_SuperExecutorBase.CallOpts, hook, prevHook, account, hookData)
}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() view returns(string)
func (_SuperExecutorBase *SuperExecutorBaseCaller) Version(opts *bind.CallOpts) (string, error) {
	var out []interface{}
	err := _SuperExecutorBase.contract.Call(opts, &out, "version")

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() view returns(string)
func (_SuperExecutorBase *SuperExecutorBaseSession) Version() (string, error) {
	return _SuperExecutorBase.Contract.Version(&_SuperExecutorBase.CallOpts)
}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() view returns(string)
func (_SuperExecutorBase *SuperExecutorBaseCallerSession) Version() (string, error) {
	return _SuperExecutorBase.Contract.Version(&_SuperExecutorBase.CallOpts)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_SuperExecutorBase *SuperExecutorBaseTransactor) Execute(opts *bind.TransactOpts, data []byte) (*types.Transaction, error) {
	return _SuperExecutorBase.contract.Transact(opts, "execute", data)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_SuperExecutorBase *SuperExecutorBaseSession) Execute(data []byte) (*types.Transaction, error) {
	return _SuperExecutorBase.Contract.Execute(&_SuperExecutorBase.TransactOpts, data)
}

// Execute is a paid mutator transaction binding the contract method 0x09c5eabe.
//
// Solidity: function execute(bytes data) returns()
func (_SuperExecutorBase *SuperExecutorBaseTransactorSession) Execute(data []byte) (*types.Transaction, error) {
	return _SuperExecutorBase.Contract.Execute(&_SuperExecutorBase.TransactOpts, data)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_SuperExecutorBase *SuperExecutorBaseTransactor) OnInstall(opts *bind.TransactOpts, arg0 []byte) (*types.Transaction, error) {
	return _SuperExecutorBase.contract.Transact(opts, "onInstall", arg0)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_SuperExecutorBase *SuperExecutorBaseSession) OnInstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperExecutorBase.Contract.OnInstall(&_SuperExecutorBase.TransactOpts, arg0)
}

// OnInstall is a paid mutator transaction binding the contract method 0x6d61fe70.
//
// Solidity: function onInstall(bytes ) returns()
func (_SuperExecutorBase *SuperExecutorBaseTransactorSession) OnInstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperExecutorBase.Contract.OnInstall(&_SuperExecutorBase.TransactOpts, arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperExecutorBase *SuperExecutorBaseTransactor) OnUninstall(opts *bind.TransactOpts, arg0 []byte) (*types.Transaction, error) {
	return _SuperExecutorBase.contract.Transact(opts, "onUninstall", arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperExecutorBase *SuperExecutorBaseSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperExecutorBase.Contract.OnUninstall(&_SuperExecutorBase.TransactOpts, arg0)
}

// OnUninstall is a paid mutator transaction binding the contract method 0x8a91b0e3.
//
// Solidity: function onUninstall(bytes ) returns()
func (_SuperExecutorBase *SuperExecutorBaseTransactorSession) OnUninstall(arg0 []byte) (*types.Transaction, error) {
	return _SuperExecutorBase.Contract.OnUninstall(&_SuperExecutorBase.TransactOpts, arg0)
}

// SuperExecutorBaseSuperPositionMintRequestedIterator is returned from FilterSuperPositionMintRequested and is used to iterate over the raw logs and unpacked data for SuperPositionMintRequested events raised by the SuperExecutorBase contract.
type SuperExecutorBaseSuperPositionMintRequestedIterator struct {
	Event *SuperExecutorBaseSuperPositionMintRequested // Event containing the contract specifics and raw log

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
func (it *SuperExecutorBaseSuperPositionMintRequestedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperExecutorBaseSuperPositionMintRequested)
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
		it.Event = new(SuperExecutorBaseSuperPositionMintRequested)
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
func (it *SuperExecutorBaseSuperPositionMintRequestedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperExecutorBaseSuperPositionMintRequestedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperExecutorBaseSuperPositionMintRequested represents a SuperPositionMintRequested event raised by the SuperExecutorBase contract.
type SuperExecutorBaseSuperPositionMintRequested struct {
	Account    common.Address
	SpToken    common.Address
	Amount     *big.Int
	DstChainId *big.Int
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterSuperPositionMintRequested is a free log retrieval operation binding the contract event 0x7ec946bedac80f139c7c4149ac44127f938a0ab50229c59b7c0cd5debc72c233.
//
// Solidity: event SuperPositionMintRequested(address indexed account, address indexed spToken, uint256 amount, uint256 indexed dstChainId)
func (_SuperExecutorBase *SuperExecutorBaseFilterer) FilterSuperPositionMintRequested(opts *bind.FilterOpts, account []common.Address, spToken []common.Address, dstChainId []*big.Int) (*SuperExecutorBaseSuperPositionMintRequestedIterator, error) {

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

	logs, sub, err := _SuperExecutorBase.contract.FilterLogs(opts, "SuperPositionMintRequested", accountRule, spTokenRule, dstChainIdRule)
	if err != nil {
		return nil, err
	}
	return &SuperExecutorBaseSuperPositionMintRequestedIterator{contract: _SuperExecutorBase.contract, event: "SuperPositionMintRequested", logs: logs, sub: sub}, nil
}

// WatchSuperPositionMintRequested is a free log subscription operation binding the contract event 0x7ec946bedac80f139c7c4149ac44127f938a0ab50229c59b7c0cd5debc72c233.
//
// Solidity: event SuperPositionMintRequested(address indexed account, address indexed spToken, uint256 amount, uint256 indexed dstChainId)
func (_SuperExecutorBase *SuperExecutorBaseFilterer) WatchSuperPositionMintRequested(opts *bind.WatchOpts, sink chan<- *SuperExecutorBaseSuperPositionMintRequested, account []common.Address, spToken []common.Address, dstChainId []*big.Int) (event.Subscription, error) {

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

	logs, sub, err := _SuperExecutorBase.contract.WatchLogs(opts, "SuperPositionMintRequested", accountRule, spTokenRule, dstChainIdRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperExecutorBaseSuperPositionMintRequested)
				if err := _SuperExecutorBase.contract.UnpackLog(event, "SuperPositionMintRequested", log); err != nil {
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
func (_SuperExecutorBase *SuperExecutorBaseFilterer) ParseSuperPositionMintRequested(log types.Log) (*SuperExecutorBaseSuperPositionMintRequested, error) {
	event := new(SuperExecutorBaseSuperPositionMintRequested)
	if err := _SuperExecutorBase.contract.UnpackLog(event, "SuperPositionMintRequested", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
