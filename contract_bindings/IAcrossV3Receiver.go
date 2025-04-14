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

// IAcrossV3ReceiverMetaData contains all meta data concerning the IAcrossV3Receiver contract.
var IAcrossV3ReceiverMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"handleV3AcrossMessage\",\"inputs\":[{\"name\":\"tokenSent\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"relayer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"message\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"AcrossFundsReceivedAndExecuted\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AcrossFundsReceivedButExecutionFailed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AcrossFundsReceivedButNotEnoughBalance\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"INVALID_SENDER\",\"inputs\":[]}]",
}

// IAcrossV3ReceiverABI is the input ABI used to generate the binding from.
// Deprecated: Use IAcrossV3ReceiverMetaData.ABI instead.
var IAcrossV3ReceiverABI = IAcrossV3ReceiverMetaData.ABI

// IAcrossV3Receiver is an auto generated Go binding around an Ethereum contract.
type IAcrossV3Receiver struct {
	IAcrossV3ReceiverCaller     // Read-only binding to the contract
	IAcrossV3ReceiverTransactor // Write-only binding to the contract
	IAcrossV3ReceiverFilterer   // Log filterer for contract events
}

// IAcrossV3ReceiverCaller is an auto generated read-only Go binding around an Ethereum contract.
type IAcrossV3ReceiverCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// IAcrossV3ReceiverTransactor is an auto generated write-only Go binding around an Ethereum contract.
type IAcrossV3ReceiverTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// IAcrossV3ReceiverFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type IAcrossV3ReceiverFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// IAcrossV3ReceiverSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type IAcrossV3ReceiverSession struct {
	Contract     *IAcrossV3Receiver // Generic contract binding to set the session for
	CallOpts     bind.CallOpts      // Call options to use throughout this session
	TransactOpts bind.TransactOpts  // Transaction auth options to use throughout this session
}

// IAcrossV3ReceiverCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type IAcrossV3ReceiverCallerSession struct {
	Contract *IAcrossV3ReceiverCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts            // Call options to use throughout this session
}

// IAcrossV3ReceiverTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type IAcrossV3ReceiverTransactorSession struct {
	Contract     *IAcrossV3ReceiverTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts            // Transaction auth options to use throughout this session
}

// IAcrossV3ReceiverRaw is an auto generated low-level Go binding around an Ethereum contract.
type IAcrossV3ReceiverRaw struct {
	Contract *IAcrossV3Receiver // Generic contract binding to access the raw methods on
}

// IAcrossV3ReceiverCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type IAcrossV3ReceiverCallerRaw struct {
	Contract *IAcrossV3ReceiverCaller // Generic read-only contract binding to access the raw methods on
}

// IAcrossV3ReceiverTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type IAcrossV3ReceiverTransactorRaw struct {
	Contract *IAcrossV3ReceiverTransactor // Generic write-only contract binding to access the raw methods on
}

// NewIAcrossV3Receiver creates a new instance of IAcrossV3Receiver, bound to a specific deployed contract.
func NewIAcrossV3Receiver(address common.Address, backend bind.ContractBackend) (*IAcrossV3Receiver, error) {
	contract, err := bindIAcrossV3Receiver(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &IAcrossV3Receiver{IAcrossV3ReceiverCaller: IAcrossV3ReceiverCaller{contract: contract}, IAcrossV3ReceiverTransactor: IAcrossV3ReceiverTransactor{contract: contract}, IAcrossV3ReceiverFilterer: IAcrossV3ReceiverFilterer{contract: contract}}, nil
}

// NewIAcrossV3ReceiverCaller creates a new read-only instance of IAcrossV3Receiver, bound to a specific deployed contract.
func NewIAcrossV3ReceiverCaller(address common.Address, caller bind.ContractCaller) (*IAcrossV3ReceiverCaller, error) {
	contract, err := bindIAcrossV3Receiver(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &IAcrossV3ReceiverCaller{contract: contract}, nil
}

// NewIAcrossV3ReceiverTransactor creates a new write-only instance of IAcrossV3Receiver, bound to a specific deployed contract.
func NewIAcrossV3ReceiverTransactor(address common.Address, transactor bind.ContractTransactor) (*IAcrossV3ReceiverTransactor, error) {
	contract, err := bindIAcrossV3Receiver(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &IAcrossV3ReceiverTransactor{contract: contract}, nil
}

// NewIAcrossV3ReceiverFilterer creates a new log filterer instance of IAcrossV3Receiver, bound to a specific deployed contract.
func NewIAcrossV3ReceiverFilterer(address common.Address, filterer bind.ContractFilterer) (*IAcrossV3ReceiverFilterer, error) {
	contract, err := bindIAcrossV3Receiver(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &IAcrossV3ReceiverFilterer{contract: contract}, nil
}

// bindIAcrossV3Receiver binds a generic wrapper to an already deployed contract.
func bindIAcrossV3Receiver(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := IAcrossV3ReceiverMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_IAcrossV3Receiver *IAcrossV3ReceiverRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _IAcrossV3Receiver.Contract.IAcrossV3ReceiverCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_IAcrossV3Receiver *IAcrossV3ReceiverRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _IAcrossV3Receiver.Contract.IAcrossV3ReceiverTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_IAcrossV3Receiver *IAcrossV3ReceiverRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _IAcrossV3Receiver.Contract.IAcrossV3ReceiverTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_IAcrossV3Receiver *IAcrossV3ReceiverCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _IAcrossV3Receiver.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_IAcrossV3Receiver *IAcrossV3ReceiverTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _IAcrossV3Receiver.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_IAcrossV3Receiver *IAcrossV3ReceiverTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _IAcrossV3Receiver.Contract.contract.Transact(opts, method, params...)
}

// HandleV3AcrossMessage is a paid mutator transaction binding the contract method 0x3a5be8cb.
//
// Solidity: function handleV3AcrossMessage(address tokenSent, uint256 amount, address relayer, bytes message) returns()
func (_IAcrossV3Receiver *IAcrossV3ReceiverTransactor) HandleV3AcrossMessage(opts *bind.TransactOpts, tokenSent common.Address, amount *big.Int, relayer common.Address, message []byte) (*types.Transaction, error) {
	return _IAcrossV3Receiver.contract.Transact(opts, "handleV3AcrossMessage", tokenSent, amount, relayer, message)
}

// HandleV3AcrossMessage is a paid mutator transaction binding the contract method 0x3a5be8cb.
//
// Solidity: function handleV3AcrossMessage(address tokenSent, uint256 amount, address relayer, bytes message) returns()
func (_IAcrossV3Receiver *IAcrossV3ReceiverSession) HandleV3AcrossMessage(tokenSent common.Address, amount *big.Int, relayer common.Address, message []byte) (*types.Transaction, error) {
	return _IAcrossV3Receiver.Contract.HandleV3AcrossMessage(&_IAcrossV3Receiver.TransactOpts, tokenSent, amount, relayer, message)
}

// HandleV3AcrossMessage is a paid mutator transaction binding the contract method 0x3a5be8cb.
//
// Solidity: function handleV3AcrossMessage(address tokenSent, uint256 amount, address relayer, bytes message) returns()
func (_IAcrossV3Receiver *IAcrossV3ReceiverTransactorSession) HandleV3AcrossMessage(tokenSent common.Address, amount *big.Int, relayer common.Address, message []byte) (*types.Transaction, error) {
	return _IAcrossV3Receiver.Contract.HandleV3AcrossMessage(&_IAcrossV3Receiver.TransactOpts, tokenSent, amount, relayer, message)
}

// IAcrossV3ReceiverAcrossFundsReceivedAndExecutedIterator is returned from FilterAcrossFundsReceivedAndExecuted and is used to iterate over the raw logs and unpacked data for AcrossFundsReceivedAndExecuted events raised by the IAcrossV3Receiver contract.
type IAcrossV3ReceiverAcrossFundsReceivedAndExecutedIterator struct {
	Event *IAcrossV3ReceiverAcrossFundsReceivedAndExecuted // Event containing the contract specifics and raw log

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
func (it *IAcrossV3ReceiverAcrossFundsReceivedAndExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(IAcrossV3ReceiverAcrossFundsReceivedAndExecuted)
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
		it.Event = new(IAcrossV3ReceiverAcrossFundsReceivedAndExecuted)
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
func (it *IAcrossV3ReceiverAcrossFundsReceivedAndExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *IAcrossV3ReceiverAcrossFundsReceivedAndExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// IAcrossV3ReceiverAcrossFundsReceivedAndExecuted represents a AcrossFundsReceivedAndExecuted event raised by the IAcrossV3Receiver contract.
type IAcrossV3ReceiverAcrossFundsReceivedAndExecuted struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAcrossFundsReceivedAndExecuted is a free log retrieval operation binding the contract event 0xd88a3ae4799f4e1c36d5e250d49c982bbcdc83d4ef55ed7fbfda5b201759e65f.
//
// Solidity: event AcrossFundsReceivedAndExecuted(address indexed account)
func (_IAcrossV3Receiver *IAcrossV3ReceiverFilterer) FilterAcrossFundsReceivedAndExecuted(opts *bind.FilterOpts, account []common.Address) (*IAcrossV3ReceiverAcrossFundsReceivedAndExecutedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _IAcrossV3Receiver.contract.FilterLogs(opts, "AcrossFundsReceivedAndExecuted", accountRule)
	if err != nil {
		return nil, err
	}
	return &IAcrossV3ReceiverAcrossFundsReceivedAndExecutedIterator{contract: _IAcrossV3Receiver.contract, event: "AcrossFundsReceivedAndExecuted", logs: logs, sub: sub}, nil
}

// WatchAcrossFundsReceivedAndExecuted is a free log subscription operation binding the contract event 0xd88a3ae4799f4e1c36d5e250d49c982bbcdc83d4ef55ed7fbfda5b201759e65f.
//
// Solidity: event AcrossFundsReceivedAndExecuted(address indexed account)
func (_IAcrossV3Receiver *IAcrossV3ReceiverFilterer) WatchAcrossFundsReceivedAndExecuted(opts *bind.WatchOpts, sink chan<- *IAcrossV3ReceiverAcrossFundsReceivedAndExecuted, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _IAcrossV3Receiver.contract.WatchLogs(opts, "AcrossFundsReceivedAndExecuted", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(IAcrossV3ReceiverAcrossFundsReceivedAndExecuted)
				if err := _IAcrossV3Receiver.contract.UnpackLog(event, "AcrossFundsReceivedAndExecuted", log); err != nil {
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
func (_IAcrossV3Receiver *IAcrossV3ReceiverFilterer) ParseAcrossFundsReceivedAndExecuted(log types.Log) (*IAcrossV3ReceiverAcrossFundsReceivedAndExecuted, error) {
	event := new(IAcrossV3ReceiverAcrossFundsReceivedAndExecuted)
	if err := _IAcrossV3Receiver.contract.UnpackLog(event, "AcrossFundsReceivedAndExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// IAcrossV3ReceiverAcrossFundsReceivedButExecutionFailedIterator is returned from FilterAcrossFundsReceivedButExecutionFailed and is used to iterate over the raw logs and unpacked data for AcrossFundsReceivedButExecutionFailed events raised by the IAcrossV3Receiver contract.
type IAcrossV3ReceiverAcrossFundsReceivedButExecutionFailedIterator struct {
	Event *IAcrossV3ReceiverAcrossFundsReceivedButExecutionFailed // Event containing the contract specifics and raw log

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
func (it *IAcrossV3ReceiverAcrossFundsReceivedButExecutionFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(IAcrossV3ReceiverAcrossFundsReceivedButExecutionFailed)
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
		it.Event = new(IAcrossV3ReceiverAcrossFundsReceivedButExecutionFailed)
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
func (it *IAcrossV3ReceiverAcrossFundsReceivedButExecutionFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *IAcrossV3ReceiverAcrossFundsReceivedButExecutionFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// IAcrossV3ReceiverAcrossFundsReceivedButExecutionFailed represents a AcrossFundsReceivedButExecutionFailed event raised by the IAcrossV3Receiver contract.
type IAcrossV3ReceiverAcrossFundsReceivedButExecutionFailed struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAcrossFundsReceivedButExecutionFailed is a free log retrieval operation binding the contract event 0x04c138373117f58fea06058b5a537a58b5a5324f226667d219560baa728b609a.
//
// Solidity: event AcrossFundsReceivedButExecutionFailed(address indexed account)
func (_IAcrossV3Receiver *IAcrossV3ReceiverFilterer) FilterAcrossFundsReceivedButExecutionFailed(opts *bind.FilterOpts, account []common.Address) (*IAcrossV3ReceiverAcrossFundsReceivedButExecutionFailedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _IAcrossV3Receiver.contract.FilterLogs(opts, "AcrossFundsReceivedButExecutionFailed", accountRule)
	if err != nil {
		return nil, err
	}
	return &IAcrossV3ReceiverAcrossFundsReceivedButExecutionFailedIterator{contract: _IAcrossV3Receiver.contract, event: "AcrossFundsReceivedButExecutionFailed", logs: logs, sub: sub}, nil
}

// WatchAcrossFundsReceivedButExecutionFailed is a free log subscription operation binding the contract event 0x04c138373117f58fea06058b5a537a58b5a5324f226667d219560baa728b609a.
//
// Solidity: event AcrossFundsReceivedButExecutionFailed(address indexed account)
func (_IAcrossV3Receiver *IAcrossV3ReceiverFilterer) WatchAcrossFundsReceivedButExecutionFailed(opts *bind.WatchOpts, sink chan<- *IAcrossV3ReceiverAcrossFundsReceivedButExecutionFailed, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _IAcrossV3Receiver.contract.WatchLogs(opts, "AcrossFundsReceivedButExecutionFailed", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(IAcrossV3ReceiverAcrossFundsReceivedButExecutionFailed)
				if err := _IAcrossV3Receiver.contract.UnpackLog(event, "AcrossFundsReceivedButExecutionFailed", log); err != nil {
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
func (_IAcrossV3Receiver *IAcrossV3ReceiverFilterer) ParseAcrossFundsReceivedButExecutionFailed(log types.Log) (*IAcrossV3ReceiverAcrossFundsReceivedButExecutionFailed, error) {
	event := new(IAcrossV3ReceiverAcrossFundsReceivedButExecutionFailed)
	if err := _IAcrossV3Receiver.contract.UnpackLog(event, "AcrossFundsReceivedButExecutionFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// IAcrossV3ReceiverAcrossFundsReceivedButNotEnoughBalanceIterator is returned from FilterAcrossFundsReceivedButNotEnoughBalance and is used to iterate over the raw logs and unpacked data for AcrossFundsReceivedButNotEnoughBalance events raised by the IAcrossV3Receiver contract.
type IAcrossV3ReceiverAcrossFundsReceivedButNotEnoughBalanceIterator struct {
	Event *IAcrossV3ReceiverAcrossFundsReceivedButNotEnoughBalance // Event containing the contract specifics and raw log

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
func (it *IAcrossV3ReceiverAcrossFundsReceivedButNotEnoughBalanceIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(IAcrossV3ReceiverAcrossFundsReceivedButNotEnoughBalance)
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
		it.Event = new(IAcrossV3ReceiverAcrossFundsReceivedButNotEnoughBalance)
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
func (it *IAcrossV3ReceiverAcrossFundsReceivedButNotEnoughBalanceIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *IAcrossV3ReceiverAcrossFundsReceivedButNotEnoughBalanceIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// IAcrossV3ReceiverAcrossFundsReceivedButNotEnoughBalance represents a AcrossFundsReceivedButNotEnoughBalance event raised by the IAcrossV3Receiver contract.
type IAcrossV3ReceiverAcrossFundsReceivedButNotEnoughBalance struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAcrossFundsReceivedButNotEnoughBalance is a free log retrieval operation binding the contract event 0xb86165879c164ced5021b2b5c5c559281e991c7171a39df5b2699f900a9f3ebe.
//
// Solidity: event AcrossFundsReceivedButNotEnoughBalance(address indexed account)
func (_IAcrossV3Receiver *IAcrossV3ReceiverFilterer) FilterAcrossFundsReceivedButNotEnoughBalance(opts *bind.FilterOpts, account []common.Address) (*IAcrossV3ReceiverAcrossFundsReceivedButNotEnoughBalanceIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _IAcrossV3Receiver.contract.FilterLogs(opts, "AcrossFundsReceivedButNotEnoughBalance", accountRule)
	if err != nil {
		return nil, err
	}
	return &IAcrossV3ReceiverAcrossFundsReceivedButNotEnoughBalanceIterator{contract: _IAcrossV3Receiver.contract, event: "AcrossFundsReceivedButNotEnoughBalance", logs: logs, sub: sub}, nil
}

// WatchAcrossFundsReceivedButNotEnoughBalance is a free log subscription operation binding the contract event 0xb86165879c164ced5021b2b5c5c559281e991c7171a39df5b2699f900a9f3ebe.
//
// Solidity: event AcrossFundsReceivedButNotEnoughBalance(address indexed account)
func (_IAcrossV3Receiver *IAcrossV3ReceiverFilterer) WatchAcrossFundsReceivedButNotEnoughBalance(opts *bind.WatchOpts, sink chan<- *IAcrossV3ReceiverAcrossFundsReceivedButNotEnoughBalance, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _IAcrossV3Receiver.contract.WatchLogs(opts, "AcrossFundsReceivedButNotEnoughBalance", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(IAcrossV3ReceiverAcrossFundsReceivedButNotEnoughBalance)
				if err := _IAcrossV3Receiver.contract.UnpackLog(event, "AcrossFundsReceivedButNotEnoughBalance", log); err != nil {
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
func (_IAcrossV3Receiver *IAcrossV3ReceiverFilterer) ParseAcrossFundsReceivedButNotEnoughBalance(log types.Log) (*IAcrossV3ReceiverAcrossFundsReceivedButNotEnoughBalance, error) {
	event := new(IAcrossV3ReceiverAcrossFundsReceivedButNotEnoughBalance)
	if err := _IAcrossV3Receiver.contract.UnpackLog(event, "AcrossFundsReceivedButNotEnoughBalance", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
