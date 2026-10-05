// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package RegistryAdapter

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

// RegistryAdapterMetaData contains all meta data concerning the RegistryAdapter contract.
var RegistryAdapterMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"getRegistry\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIERC7484\"}],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"ERC7484RegistryConfigured\",\"inputs\":[{\"name\":\"registry\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"contractIERC7484\"}],\"anonymous\":false}]",
}

// RegistryAdapterABI is the input ABI used to generate the binding from.
// Deprecated: Use RegistryAdapterMetaData.ABI instead.
var RegistryAdapterABI = RegistryAdapterMetaData.ABI

// RegistryAdapter is an auto generated Go binding around an Ethereum contract.
type RegistryAdapter struct {
	RegistryAdapterCaller     // Read-only binding to the contract
	RegistryAdapterTransactor // Write-only binding to the contract
	RegistryAdapterFilterer   // Log filterer for contract events
}

// RegistryAdapterCaller is an auto generated read-only Go binding around an Ethereum contract.
type RegistryAdapterCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// RegistryAdapterTransactor is an auto generated write-only Go binding around an Ethereum contract.
type RegistryAdapterTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// RegistryAdapterFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type RegistryAdapterFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// RegistryAdapterSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type RegistryAdapterSession struct {
	Contract     *RegistryAdapter  // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// RegistryAdapterCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type RegistryAdapterCallerSession struct {
	Contract *RegistryAdapterCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts          // Call options to use throughout this session
}

// RegistryAdapterTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type RegistryAdapterTransactorSession struct {
	Contract     *RegistryAdapterTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts          // Transaction auth options to use throughout this session
}

// RegistryAdapterRaw is an auto generated low-level Go binding around an Ethereum contract.
type RegistryAdapterRaw struct {
	Contract *RegistryAdapter // Generic contract binding to access the raw methods on
}

// RegistryAdapterCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type RegistryAdapterCallerRaw struct {
	Contract *RegistryAdapterCaller // Generic read-only contract binding to access the raw methods on
}

// RegistryAdapterTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type RegistryAdapterTransactorRaw struct {
	Contract *RegistryAdapterTransactor // Generic write-only contract binding to access the raw methods on
}

// NewRegistryAdapter creates a new instance of RegistryAdapter, bound to a specific deployed contract.
func NewRegistryAdapter(address common.Address, backend bind.ContractBackend) (*RegistryAdapter, error) {
	contract, err := bindRegistryAdapter(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &RegistryAdapter{RegistryAdapterCaller: RegistryAdapterCaller{contract: contract}, RegistryAdapterTransactor: RegistryAdapterTransactor{contract: contract}, RegistryAdapterFilterer: RegistryAdapterFilterer{contract: contract}}, nil
}

// NewRegistryAdapterCaller creates a new read-only instance of RegistryAdapter, bound to a specific deployed contract.
func NewRegistryAdapterCaller(address common.Address, caller bind.ContractCaller) (*RegistryAdapterCaller, error) {
	contract, err := bindRegistryAdapter(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &RegistryAdapterCaller{contract: contract}, nil
}

// NewRegistryAdapterTransactor creates a new write-only instance of RegistryAdapter, bound to a specific deployed contract.
func NewRegistryAdapterTransactor(address common.Address, transactor bind.ContractTransactor) (*RegistryAdapterTransactor, error) {
	contract, err := bindRegistryAdapter(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &RegistryAdapterTransactor{contract: contract}, nil
}

// NewRegistryAdapterFilterer creates a new log filterer instance of RegistryAdapter, bound to a specific deployed contract.
func NewRegistryAdapterFilterer(address common.Address, filterer bind.ContractFilterer) (*RegistryAdapterFilterer, error) {
	contract, err := bindRegistryAdapter(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &RegistryAdapterFilterer{contract: contract}, nil
}

// bindRegistryAdapter binds a generic wrapper to an already deployed contract.
func bindRegistryAdapter(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := RegistryAdapterMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_RegistryAdapter *RegistryAdapterRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _RegistryAdapter.Contract.RegistryAdapterCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_RegistryAdapter *RegistryAdapterRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _RegistryAdapter.Contract.RegistryAdapterTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_RegistryAdapter *RegistryAdapterRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _RegistryAdapter.Contract.RegistryAdapterTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_RegistryAdapter *RegistryAdapterCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _RegistryAdapter.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_RegistryAdapter *RegistryAdapterTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _RegistryAdapter.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_RegistryAdapter *RegistryAdapterTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _RegistryAdapter.Contract.contract.Transact(opts, method, params...)
}

// GetRegistry is a free data retrieval call binding the contract method 0x5ab1bd53.
//
// Solidity: function getRegistry() view returns(address)
func (_RegistryAdapter *RegistryAdapterCaller) GetRegistry(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _RegistryAdapter.contract.Call(opts, &out, "getRegistry")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetRegistry is a free data retrieval call binding the contract method 0x5ab1bd53.
//
// Solidity: function getRegistry() view returns(address)
func (_RegistryAdapter *RegistryAdapterSession) GetRegistry() (common.Address, error) {
	return _RegistryAdapter.Contract.GetRegistry(&_RegistryAdapter.CallOpts)
}

// GetRegistry is a free data retrieval call binding the contract method 0x5ab1bd53.
//
// Solidity: function getRegistry() view returns(address)
func (_RegistryAdapter *RegistryAdapterCallerSession) GetRegistry() (common.Address, error) {
	return _RegistryAdapter.Contract.GetRegistry(&_RegistryAdapter.CallOpts)
}

// RegistryAdapterERC7484RegistryConfiguredIterator is returned from FilterERC7484RegistryConfigured and is used to iterate over the raw logs and unpacked data for ERC7484RegistryConfigured events raised by the RegistryAdapter contract.
type RegistryAdapterERC7484RegistryConfiguredIterator struct {
	Event *RegistryAdapterERC7484RegistryConfigured // Event containing the contract specifics and raw log

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
func (it *RegistryAdapterERC7484RegistryConfiguredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RegistryAdapterERC7484RegistryConfigured)
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
		it.Event = new(RegistryAdapterERC7484RegistryConfigured)
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
func (it *RegistryAdapterERC7484RegistryConfiguredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RegistryAdapterERC7484RegistryConfiguredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RegistryAdapterERC7484RegistryConfigured represents a ERC7484RegistryConfigured event raised by the RegistryAdapter contract.
type RegistryAdapterERC7484RegistryConfigured struct {
	Registry common.Address
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterERC7484RegistryConfigured is a free log retrieval operation binding the contract event 0xf98c8404c5b1bfef2e6ba9233c6e88845aedfd36eea8b192725d8c199571cf32.
//
// Solidity: event ERC7484RegistryConfigured(address indexed registry)
func (_RegistryAdapter *RegistryAdapterFilterer) FilterERC7484RegistryConfigured(opts *bind.FilterOpts, registry []common.Address) (*RegistryAdapterERC7484RegistryConfiguredIterator, error) {

	var registryRule []interface{}
	for _, registryItem := range registry {
		registryRule = append(registryRule, registryItem)
	}

	logs, sub, err := _RegistryAdapter.contract.FilterLogs(opts, "ERC7484RegistryConfigured", registryRule)
	if err != nil {
		return nil, err
	}
	return &RegistryAdapterERC7484RegistryConfiguredIterator{contract: _RegistryAdapter.contract, event: "ERC7484RegistryConfigured", logs: logs, sub: sub}, nil
}

// WatchERC7484RegistryConfigured is a free log subscription operation binding the contract event 0xf98c8404c5b1bfef2e6ba9233c6e88845aedfd36eea8b192725d8c199571cf32.
//
// Solidity: event ERC7484RegistryConfigured(address indexed registry)
func (_RegistryAdapter *RegistryAdapterFilterer) WatchERC7484RegistryConfigured(opts *bind.WatchOpts, sink chan<- *RegistryAdapterERC7484RegistryConfigured, registry []common.Address) (event.Subscription, error) {

	var registryRule []interface{}
	for _, registryItem := range registry {
		registryRule = append(registryRule, registryItem)
	}

	logs, sub, err := _RegistryAdapter.contract.WatchLogs(opts, "ERC7484RegistryConfigured", registryRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RegistryAdapterERC7484RegistryConfigured)
				if err := _RegistryAdapter.contract.UnpackLog(event, "ERC7484RegistryConfigured", log); err != nil {
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

// ParseERC7484RegistryConfigured is a log parse operation binding the contract event 0xf98c8404c5b1bfef2e6ba9233c6e88845aedfd36eea8b192725d8c199571cf32.
//
// Solidity: event ERC7484RegistryConfigured(address indexed registry)
func (_RegistryAdapter *RegistryAdapterFilterer) ParseERC7484RegistryConfigured(log types.Log) (*RegistryAdapterERC7484RegistryConfigured, error) {
	event := new(RegistryAdapterERC7484RegistryConfigured)
	if err := _RegistryAdapter.contract.UnpackLog(event, "ERC7484RegistryConfigured", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
