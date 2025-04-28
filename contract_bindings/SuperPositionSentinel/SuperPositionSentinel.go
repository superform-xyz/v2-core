// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package SuperPositionSentinel

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

// SuperPositionSentinelMetaData contains all meta data concerning the SuperPositionSentinel contract.
var SuperPositionSentinelMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"notify\",\"inputs\":[{\"name\":\"actionId_\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"finalTarget_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"entry_\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"Processed\",\"inputs\":[{\"name\":\"actionId\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"yieldSourceAddress\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperPositionBurn\",\"inputs\":[{\"name\":\"actionId_\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"finalTarget_\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount_\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SuperPositionMint\",\"inputs\":[{\"name\":\"actionId_\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"finalTarget_\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount_\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NOT_AUTHORIZED\",\"inputs\":[]}]",
}

// SuperPositionSentinelABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperPositionSentinelMetaData.ABI instead.
var SuperPositionSentinelABI = SuperPositionSentinelMetaData.ABI

// SuperPositionSentinel is an auto generated Go binding around an Ethereum contract.
type SuperPositionSentinel struct {
	SuperPositionSentinelCaller     // Read-only binding to the contract
	SuperPositionSentinelTransactor // Write-only binding to the contract
	SuperPositionSentinelFilterer   // Log filterer for contract events
}

// SuperPositionSentinelCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperPositionSentinelCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperPositionSentinelTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperPositionSentinelTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperPositionSentinelFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperPositionSentinelFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperPositionSentinelSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperPositionSentinelSession struct {
	Contract     *SuperPositionSentinel // Generic contract binding to set the session for
	CallOpts     bind.CallOpts          // Call options to use throughout this session
	TransactOpts bind.TransactOpts      // Transaction auth options to use throughout this session
}

// SuperPositionSentinelCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperPositionSentinelCallerSession struct {
	Contract *SuperPositionSentinelCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                // Call options to use throughout this session
}

// SuperPositionSentinelTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperPositionSentinelTransactorSession struct {
	Contract     *SuperPositionSentinelTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                // Transaction auth options to use throughout this session
}

// SuperPositionSentinelRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperPositionSentinelRaw struct {
	Contract *SuperPositionSentinel // Generic contract binding to access the raw methods on
}

// SuperPositionSentinelCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperPositionSentinelCallerRaw struct {
	Contract *SuperPositionSentinelCaller // Generic read-only contract binding to access the raw methods on
}

// SuperPositionSentinelTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperPositionSentinelTransactorRaw struct {
	Contract *SuperPositionSentinelTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperPositionSentinel creates a new instance of SuperPositionSentinel, bound to a specific deployed contract.
func NewSuperPositionSentinel(address common.Address, backend bind.ContractBackend) (*SuperPositionSentinel, error) {
	contract, err := bindSuperPositionSentinel(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperPositionSentinel{SuperPositionSentinelCaller: SuperPositionSentinelCaller{contract: contract}, SuperPositionSentinelTransactor: SuperPositionSentinelTransactor{contract: contract}, SuperPositionSentinelFilterer: SuperPositionSentinelFilterer{contract: contract}}, nil
}

// NewSuperPositionSentinelCaller creates a new read-only instance of SuperPositionSentinel, bound to a specific deployed contract.
func NewSuperPositionSentinelCaller(address common.Address, caller bind.ContractCaller) (*SuperPositionSentinelCaller, error) {
	contract, err := bindSuperPositionSentinel(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperPositionSentinelCaller{contract: contract}, nil
}

// NewSuperPositionSentinelTransactor creates a new write-only instance of SuperPositionSentinel, bound to a specific deployed contract.
func NewSuperPositionSentinelTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperPositionSentinelTransactor, error) {
	contract, err := bindSuperPositionSentinel(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperPositionSentinelTransactor{contract: contract}, nil
}

// NewSuperPositionSentinelFilterer creates a new log filterer instance of SuperPositionSentinel, bound to a specific deployed contract.
func NewSuperPositionSentinelFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperPositionSentinelFilterer, error) {
	contract, err := bindSuperPositionSentinel(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperPositionSentinelFilterer{contract: contract}, nil
}

// bindSuperPositionSentinel binds a generic wrapper to an already deployed contract.
func bindSuperPositionSentinel(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperPositionSentinelMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperPositionSentinel *SuperPositionSentinelRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperPositionSentinel.Contract.SuperPositionSentinelCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperPositionSentinel *SuperPositionSentinelRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperPositionSentinel.Contract.SuperPositionSentinelTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperPositionSentinel *SuperPositionSentinelRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperPositionSentinel.Contract.SuperPositionSentinelTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperPositionSentinel *SuperPositionSentinelCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperPositionSentinel.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperPositionSentinel *SuperPositionSentinelTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperPositionSentinel.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperPositionSentinel *SuperPositionSentinelTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperPositionSentinel.Contract.contract.Transact(opts, method, params...)
}

// Notify is a paid mutator transaction binding the contract method 0x185bed0f.
//
// Solidity: function notify(uint256 actionId_, address finalTarget_, bytes entry_) returns()
func (_SuperPositionSentinel *SuperPositionSentinelTransactor) Notify(opts *bind.TransactOpts, actionId_ *big.Int, finalTarget_ common.Address, entry_ []byte) (*types.Transaction, error) {
	return _SuperPositionSentinel.contract.Transact(opts, "notify", actionId_, finalTarget_, entry_)
}

// Notify is a paid mutator transaction binding the contract method 0x185bed0f.
//
// Solidity: function notify(uint256 actionId_, address finalTarget_, bytes entry_) returns()
func (_SuperPositionSentinel *SuperPositionSentinelSession) Notify(actionId_ *big.Int, finalTarget_ common.Address, entry_ []byte) (*types.Transaction, error) {
	return _SuperPositionSentinel.Contract.Notify(&_SuperPositionSentinel.TransactOpts, actionId_, finalTarget_, entry_)
}

// Notify is a paid mutator transaction binding the contract method 0x185bed0f.
//
// Solidity: function notify(uint256 actionId_, address finalTarget_, bytes entry_) returns()
func (_SuperPositionSentinel *SuperPositionSentinelTransactorSession) Notify(actionId_ *big.Int, finalTarget_ common.Address, entry_ []byte) (*types.Transaction, error) {
	return _SuperPositionSentinel.Contract.Notify(&_SuperPositionSentinel.TransactOpts, actionId_, finalTarget_, entry_)
}

// SuperPositionSentinelProcessedIterator is returned from FilterProcessed and is used to iterate over the raw logs and unpacked data for Processed events raised by the SuperPositionSentinel contract.
type SuperPositionSentinelProcessedIterator struct {
	Event *SuperPositionSentinelProcessed // Event containing the contract specifics and raw log

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
func (it *SuperPositionSentinelProcessedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperPositionSentinelProcessed)
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
		it.Event = new(SuperPositionSentinelProcessed)
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
func (it *SuperPositionSentinelProcessedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperPositionSentinelProcessedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperPositionSentinelProcessed represents a Processed event raised by the SuperPositionSentinel contract.
type SuperPositionSentinelProcessed struct {
	ActionId           *big.Int
	YieldSourceAddress common.Address
	Raw                types.Log // Blockchain specific contextual infos
}

// FilterProcessed is a free log retrieval operation binding the contract event 0x86a9fd0241dd7d84eb1203528b8f8827adf43f721495afbbcc8f3d01d25e00b9.
//
// Solidity: event Processed(uint256 actionId, address yieldSourceAddress)
func (_SuperPositionSentinel *SuperPositionSentinelFilterer) FilterProcessed(opts *bind.FilterOpts) (*SuperPositionSentinelProcessedIterator, error) {

	logs, sub, err := _SuperPositionSentinel.contract.FilterLogs(opts, "Processed")
	if err != nil {
		return nil, err
	}
	return &SuperPositionSentinelProcessedIterator{contract: _SuperPositionSentinel.contract, event: "Processed", logs: logs, sub: sub}, nil
}

// WatchProcessed is a free log subscription operation binding the contract event 0x86a9fd0241dd7d84eb1203528b8f8827adf43f721495afbbcc8f3d01d25e00b9.
//
// Solidity: event Processed(uint256 actionId, address yieldSourceAddress)
func (_SuperPositionSentinel *SuperPositionSentinelFilterer) WatchProcessed(opts *bind.WatchOpts, sink chan<- *SuperPositionSentinelProcessed) (event.Subscription, error) {

	logs, sub, err := _SuperPositionSentinel.contract.WatchLogs(opts, "Processed")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperPositionSentinelProcessed)
				if err := _SuperPositionSentinel.contract.UnpackLog(event, "Processed", log); err != nil {
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

// ParseProcessed is a log parse operation binding the contract event 0x86a9fd0241dd7d84eb1203528b8f8827adf43f721495afbbcc8f3d01d25e00b9.
//
// Solidity: event Processed(uint256 actionId, address yieldSourceAddress)
func (_SuperPositionSentinel *SuperPositionSentinelFilterer) ParseProcessed(log types.Log) (*SuperPositionSentinelProcessed, error) {
	event := new(SuperPositionSentinelProcessed)
	if err := _SuperPositionSentinel.contract.UnpackLog(event, "Processed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperPositionSentinelSuperPositionBurnIterator is returned from FilterSuperPositionBurn and is used to iterate over the raw logs and unpacked data for SuperPositionBurn events raised by the SuperPositionSentinel contract.
type SuperPositionSentinelSuperPositionBurnIterator struct {
	Event *SuperPositionSentinelSuperPositionBurn // Event containing the contract specifics and raw log

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
func (it *SuperPositionSentinelSuperPositionBurnIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperPositionSentinelSuperPositionBurn)
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
		it.Event = new(SuperPositionSentinelSuperPositionBurn)
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
func (it *SuperPositionSentinelSuperPositionBurnIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperPositionSentinelSuperPositionBurnIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperPositionSentinelSuperPositionBurn represents a SuperPositionBurn event raised by the SuperPositionSentinel contract.
type SuperPositionSentinelSuperPositionBurn struct {
	ActionId    *big.Int
	FinalTarget common.Address
	Amount      *big.Int
	Raw         types.Log // Blockchain specific contextual infos
}

// FilterSuperPositionBurn is a free log retrieval operation binding the contract event 0xfdbc8a3ad8d9070c1b9242cc519117ffcc3a101dcbed182e38986a41172008c9.
//
// Solidity: event SuperPositionBurn(uint256 indexed actionId_, address indexed finalTarget_, uint256 amount_)
func (_SuperPositionSentinel *SuperPositionSentinelFilterer) FilterSuperPositionBurn(opts *bind.FilterOpts, actionId_ []*big.Int, finalTarget_ []common.Address) (*SuperPositionSentinelSuperPositionBurnIterator, error) {

	var actionId_Rule []interface{}
	for _, actionId_Item := range actionId_ {
		actionId_Rule = append(actionId_Rule, actionId_Item)
	}
	var finalTarget_Rule []interface{}
	for _, finalTarget_Item := range finalTarget_ {
		finalTarget_Rule = append(finalTarget_Rule, finalTarget_Item)
	}

	logs, sub, err := _SuperPositionSentinel.contract.FilterLogs(opts, "SuperPositionBurn", actionId_Rule, finalTarget_Rule)
	if err != nil {
		return nil, err
	}
	return &SuperPositionSentinelSuperPositionBurnIterator{contract: _SuperPositionSentinel.contract, event: "SuperPositionBurn", logs: logs, sub: sub}, nil
}

// WatchSuperPositionBurn is a free log subscription operation binding the contract event 0xfdbc8a3ad8d9070c1b9242cc519117ffcc3a101dcbed182e38986a41172008c9.
//
// Solidity: event SuperPositionBurn(uint256 indexed actionId_, address indexed finalTarget_, uint256 amount_)
func (_SuperPositionSentinel *SuperPositionSentinelFilterer) WatchSuperPositionBurn(opts *bind.WatchOpts, sink chan<- *SuperPositionSentinelSuperPositionBurn, actionId_ []*big.Int, finalTarget_ []common.Address) (event.Subscription, error) {

	var actionId_Rule []interface{}
	for _, actionId_Item := range actionId_ {
		actionId_Rule = append(actionId_Rule, actionId_Item)
	}
	var finalTarget_Rule []interface{}
	for _, finalTarget_Item := range finalTarget_ {
		finalTarget_Rule = append(finalTarget_Rule, finalTarget_Item)
	}

	logs, sub, err := _SuperPositionSentinel.contract.WatchLogs(opts, "SuperPositionBurn", actionId_Rule, finalTarget_Rule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperPositionSentinelSuperPositionBurn)
				if err := _SuperPositionSentinel.contract.UnpackLog(event, "SuperPositionBurn", log); err != nil {
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

// ParseSuperPositionBurn is a log parse operation binding the contract event 0xfdbc8a3ad8d9070c1b9242cc519117ffcc3a101dcbed182e38986a41172008c9.
//
// Solidity: event SuperPositionBurn(uint256 indexed actionId_, address indexed finalTarget_, uint256 amount_)
func (_SuperPositionSentinel *SuperPositionSentinelFilterer) ParseSuperPositionBurn(log types.Log) (*SuperPositionSentinelSuperPositionBurn, error) {
	event := new(SuperPositionSentinelSuperPositionBurn)
	if err := _SuperPositionSentinel.contract.UnpackLog(event, "SuperPositionBurn", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperPositionSentinelSuperPositionMintIterator is returned from FilterSuperPositionMint and is used to iterate over the raw logs and unpacked data for SuperPositionMint events raised by the SuperPositionSentinel contract.
type SuperPositionSentinelSuperPositionMintIterator struct {
	Event *SuperPositionSentinelSuperPositionMint // Event containing the contract specifics and raw log

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
func (it *SuperPositionSentinelSuperPositionMintIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperPositionSentinelSuperPositionMint)
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
		it.Event = new(SuperPositionSentinelSuperPositionMint)
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
func (it *SuperPositionSentinelSuperPositionMintIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperPositionSentinelSuperPositionMintIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperPositionSentinelSuperPositionMint represents a SuperPositionMint event raised by the SuperPositionSentinel contract.
type SuperPositionSentinelSuperPositionMint struct {
	ActionId    *big.Int
	FinalTarget common.Address
	Amount      *big.Int
	Raw         types.Log // Blockchain specific contextual infos
}

// FilterSuperPositionMint is a free log retrieval operation binding the contract event 0xe42d923ba4525070041b19e8f492621040cf774ac4007e38807e376929564494.
//
// Solidity: event SuperPositionMint(uint256 indexed actionId_, address indexed finalTarget_, uint256 amount_)
func (_SuperPositionSentinel *SuperPositionSentinelFilterer) FilterSuperPositionMint(opts *bind.FilterOpts, actionId_ []*big.Int, finalTarget_ []common.Address) (*SuperPositionSentinelSuperPositionMintIterator, error) {

	var actionId_Rule []interface{}
	for _, actionId_Item := range actionId_ {
		actionId_Rule = append(actionId_Rule, actionId_Item)
	}
	var finalTarget_Rule []interface{}
	for _, finalTarget_Item := range finalTarget_ {
		finalTarget_Rule = append(finalTarget_Rule, finalTarget_Item)
	}

	logs, sub, err := _SuperPositionSentinel.contract.FilterLogs(opts, "SuperPositionMint", actionId_Rule, finalTarget_Rule)
	if err != nil {
		return nil, err
	}
	return &SuperPositionSentinelSuperPositionMintIterator{contract: _SuperPositionSentinel.contract, event: "SuperPositionMint", logs: logs, sub: sub}, nil
}

// WatchSuperPositionMint is a free log subscription operation binding the contract event 0xe42d923ba4525070041b19e8f492621040cf774ac4007e38807e376929564494.
//
// Solidity: event SuperPositionMint(uint256 indexed actionId_, address indexed finalTarget_, uint256 amount_)
func (_SuperPositionSentinel *SuperPositionSentinelFilterer) WatchSuperPositionMint(opts *bind.WatchOpts, sink chan<- *SuperPositionSentinelSuperPositionMint, actionId_ []*big.Int, finalTarget_ []common.Address) (event.Subscription, error) {

	var actionId_Rule []interface{}
	for _, actionId_Item := range actionId_ {
		actionId_Rule = append(actionId_Rule, actionId_Item)
	}
	var finalTarget_Rule []interface{}
	for _, finalTarget_Item := range finalTarget_ {
		finalTarget_Rule = append(finalTarget_Rule, finalTarget_Item)
	}

	logs, sub, err := _SuperPositionSentinel.contract.WatchLogs(opts, "SuperPositionMint", actionId_Rule, finalTarget_Rule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperPositionSentinelSuperPositionMint)
				if err := _SuperPositionSentinel.contract.UnpackLog(event, "SuperPositionMint", log); err != nil {
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

// ParseSuperPositionMint is a log parse operation binding the contract event 0xe42d923ba4525070041b19e8f492621040cf774ac4007e38807e376929564494.
//
// Solidity: event SuperPositionMint(uint256 indexed actionId_, address indexed finalTarget_, uint256 amount_)
func (_SuperPositionSentinel *SuperPositionSentinelFilterer) ParseSuperPositionMint(log types.Log) (*SuperPositionSentinelSuperPositionMint, error) {
	event := new(SuperPositionSentinelSuperPositionMint)
	if err := _SuperPositionSentinel.contract.UnpackLog(event, "SuperPositionMint", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
