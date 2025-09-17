// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package AcrossV3Adapter

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

// AcrossV3AdapterMetaData contains all meta data concerning the AcrossV3Adapter contract.
var AcrossV3AdapterMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"acrossSpokePool_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"superDestinationExecutor_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"ACROSS_SPOKE_POOL\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_DESTINATION_EXECUTOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperDestinationExecutor\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"handleV3AcrossMessage\",\"inputs\":[{\"name\":\"tokenSent\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"message\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"AcrossFundsReceivedAndExecuted\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AcrossFundsReceivedButExecutionFailed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AcrossFundsReceivedButNotEnoughBalance\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_SENDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SafeERC20FailedOperation\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}]}]",
}

// AcrossV3AdapterABI is the input ABI used to generate the binding from.
// Deprecated: Use AcrossV3AdapterMetaData.ABI instead.
var AcrossV3AdapterABI = AcrossV3AdapterMetaData.ABI

// AcrossV3Adapter is an auto generated Go binding around an Ethereum contract.
type AcrossV3Adapter struct {
	AcrossV3AdapterCaller     // Read-only binding to the contract
	AcrossV3AdapterTransactor // Write-only binding to the contract
	AcrossV3AdapterFilterer   // Log filterer for contract events
}

// AcrossV3AdapterCaller is an auto generated read-only Go binding around an Ethereum contract.
type AcrossV3AdapterCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AcrossV3AdapterTransactor is an auto generated write-only Go binding around an Ethereum contract.
type AcrossV3AdapterTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AcrossV3AdapterFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type AcrossV3AdapterFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AcrossV3AdapterSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type AcrossV3AdapterSession struct {
	Contract     *AcrossV3Adapter  // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// AcrossV3AdapterCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type AcrossV3AdapterCallerSession struct {
	Contract *AcrossV3AdapterCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts          // Call options to use throughout this session
}

// AcrossV3AdapterTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type AcrossV3AdapterTransactorSession struct {
	Contract     *AcrossV3AdapterTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts          // Transaction auth options to use throughout this session
}

// AcrossV3AdapterRaw is an auto generated low-level Go binding around an Ethereum contract.
type AcrossV3AdapterRaw struct {
	Contract *AcrossV3Adapter // Generic contract binding to access the raw methods on
}

// AcrossV3AdapterCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type AcrossV3AdapterCallerRaw struct {
	Contract *AcrossV3AdapterCaller // Generic read-only contract binding to access the raw methods on
}

// AcrossV3AdapterTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type AcrossV3AdapterTransactorRaw struct {
	Contract *AcrossV3AdapterTransactor // Generic write-only contract binding to access the raw methods on
}

// NewAcrossV3Adapter creates a new instance of AcrossV3Adapter, bound to a specific deployed contract.
func NewAcrossV3Adapter(address common.Address, backend bind.ContractBackend) (*AcrossV3Adapter, error) {
	contract, err := bindAcrossV3Adapter(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &AcrossV3Adapter{AcrossV3AdapterCaller: AcrossV3AdapterCaller{contract: contract}, AcrossV3AdapterTransactor: AcrossV3AdapterTransactor{contract: contract}, AcrossV3AdapterFilterer: AcrossV3AdapterFilterer{contract: contract}}, nil
}

// NewAcrossV3AdapterCaller creates a new read-only instance of AcrossV3Adapter, bound to a specific deployed contract.
func NewAcrossV3AdapterCaller(address common.Address, caller bind.ContractCaller) (*AcrossV3AdapterCaller, error) {
	contract, err := bindAcrossV3Adapter(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterCaller{contract: contract}, nil
}

// NewAcrossV3AdapterTransactor creates a new write-only instance of AcrossV3Adapter, bound to a specific deployed contract.
func NewAcrossV3AdapterTransactor(address common.Address, transactor bind.ContractTransactor) (*AcrossV3AdapterTransactor, error) {
	contract, err := bindAcrossV3Adapter(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterTransactor{contract: contract}, nil
}

// NewAcrossV3AdapterFilterer creates a new log filterer instance of AcrossV3Adapter, bound to a specific deployed contract.
func NewAcrossV3AdapterFilterer(address common.Address, filterer bind.ContractFilterer) (*AcrossV3AdapterFilterer, error) {
	contract, err := bindAcrossV3Adapter(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterFilterer{contract: contract}, nil
}

// bindAcrossV3Adapter binds a generic wrapper to an already deployed contract.
func bindAcrossV3Adapter(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := AcrossV3AdapterMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_AcrossV3Adapter *AcrossV3AdapterRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _AcrossV3Adapter.Contract.AcrossV3AdapterCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_AcrossV3Adapter *AcrossV3AdapterRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossV3Adapter.Contract.AcrossV3AdapterTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_AcrossV3Adapter *AcrossV3AdapterRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _AcrossV3Adapter.Contract.AcrossV3AdapterTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_AcrossV3Adapter *AcrossV3AdapterCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _AcrossV3Adapter.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_AcrossV3Adapter *AcrossV3AdapterTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossV3Adapter.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_AcrossV3Adapter *AcrossV3AdapterTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _AcrossV3Adapter.Contract.contract.Transact(opts, method, params...)
}

// ACROSSSPOKEPOOL is a free data retrieval call binding the contract method 0xd72b1de1.
//
// Solidity: function ACROSS_SPOKE_POOL() view returns(address)
func (_AcrossV3Adapter *AcrossV3AdapterCaller) ACROSSSPOKEPOOL(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3Adapter.contract.Call(opts, &out, "ACROSS_SPOKE_POOL")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// ACROSSSPOKEPOOL is a free data retrieval call binding the contract method 0xd72b1de1.
//
// Solidity: function ACROSS_SPOKE_POOL() view returns(address)
func (_AcrossV3Adapter *AcrossV3AdapterSession) ACROSSSPOKEPOOL() (common.Address, error) {
	return _AcrossV3Adapter.Contract.ACROSSSPOKEPOOL(&_AcrossV3Adapter.CallOpts)
}

// ACROSSSPOKEPOOL is a free data retrieval call binding the contract method 0xd72b1de1.
//
// Solidity: function ACROSS_SPOKE_POOL() view returns(address)
func (_AcrossV3Adapter *AcrossV3AdapterCallerSession) ACROSSSPOKEPOOL() (common.Address, error) {
	return _AcrossV3Adapter.Contract.ACROSSSPOKEPOOL(&_AcrossV3Adapter.CallOpts)
}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_AcrossV3Adapter *AcrossV3AdapterCaller) SUPERDESTINATIONEXECUTOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3Adapter.contract.Call(opts, &out, "SUPER_DESTINATION_EXECUTOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_AcrossV3Adapter *AcrossV3AdapterSession) SUPERDESTINATIONEXECUTOR() (common.Address, error) {
	return _AcrossV3Adapter.Contract.SUPERDESTINATIONEXECUTOR(&_AcrossV3Adapter.CallOpts)
}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_AcrossV3Adapter *AcrossV3AdapterCallerSession) SUPERDESTINATIONEXECUTOR() (common.Address, error) {
	return _AcrossV3Adapter.Contract.SUPERDESTINATIONEXECUTOR(&_AcrossV3Adapter.CallOpts)
}

// HandleV3AcrossMessage is a paid mutator transaction binding the contract method 0x3a5be8cb.
//
// Solidity: function handleV3AcrossMessage(address tokenSent, uint256 amount, address , bytes message) returns()
func (_AcrossV3Adapter *AcrossV3AdapterTransactor) HandleV3AcrossMessage(opts *bind.TransactOpts, tokenSent common.Address, amount *big.Int, arg2 common.Address, message []byte) (*types.Transaction, error) {
	return _AcrossV3Adapter.contract.Transact(opts, "handleV3AcrossMessage", tokenSent, amount, arg2, message)
}

// HandleV3AcrossMessage is a paid mutator transaction binding the contract method 0x3a5be8cb.
//
// Solidity: function handleV3AcrossMessage(address tokenSent, uint256 amount, address , bytes message) returns()
func (_AcrossV3Adapter *AcrossV3AdapterSession) HandleV3AcrossMessage(tokenSent common.Address, amount *big.Int, arg2 common.Address, message []byte) (*types.Transaction, error) {
	return _AcrossV3Adapter.Contract.HandleV3AcrossMessage(&_AcrossV3Adapter.TransactOpts, tokenSent, amount, arg2, message)
}

// HandleV3AcrossMessage is a paid mutator transaction binding the contract method 0x3a5be8cb.
//
// Solidity: function handleV3AcrossMessage(address tokenSent, uint256 amount, address , bytes message) returns()
func (_AcrossV3Adapter *AcrossV3AdapterTransactorSession) HandleV3AcrossMessage(tokenSent common.Address, amount *big.Int, arg2 common.Address, message []byte) (*types.Transaction, error) {
	return _AcrossV3Adapter.Contract.HandleV3AcrossMessage(&_AcrossV3Adapter.TransactOpts, tokenSent, amount, arg2, message)
}

// AcrossV3AdapterAcrossFundsReceivedAndExecutedIterator is returned from FilterAcrossFundsReceivedAndExecuted and is used to iterate over the raw logs and unpacked data for AcrossFundsReceivedAndExecuted events raised by the AcrossV3Adapter contract.
type AcrossV3AdapterAcrossFundsReceivedAndExecutedIterator struct {
	Event *AcrossV3AdapterAcrossFundsReceivedAndExecuted // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterAcrossFundsReceivedAndExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterAcrossFundsReceivedAndExecuted)
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
		it.Event = new(AcrossV3AdapterAcrossFundsReceivedAndExecuted)
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
func (it *AcrossV3AdapterAcrossFundsReceivedAndExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterAcrossFundsReceivedAndExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterAcrossFundsReceivedAndExecuted represents a AcrossFundsReceivedAndExecuted event raised by the AcrossV3Adapter contract.
type AcrossV3AdapterAcrossFundsReceivedAndExecuted struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAcrossFundsReceivedAndExecuted is a free log retrieval operation binding the contract event 0xd88a3ae4799f4e1c36d5e250d49c982bbcdc83d4ef55ed7fbfda5b201759e65f.
//
// Solidity: event AcrossFundsReceivedAndExecuted(address indexed account)
func (_AcrossV3Adapter *AcrossV3AdapterFilterer) FilterAcrossFundsReceivedAndExecuted(opts *bind.FilterOpts, account []common.Address) (*AcrossV3AdapterAcrossFundsReceivedAndExecutedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossV3Adapter.contract.FilterLogs(opts, "AcrossFundsReceivedAndExecuted", accountRule)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterAcrossFundsReceivedAndExecutedIterator{contract: _AcrossV3Adapter.contract, event: "AcrossFundsReceivedAndExecuted", logs: logs, sub: sub}, nil
}

// WatchAcrossFundsReceivedAndExecuted is a free log subscription operation binding the contract event 0xd88a3ae4799f4e1c36d5e250d49c982bbcdc83d4ef55ed7fbfda5b201759e65f.
//
// Solidity: event AcrossFundsReceivedAndExecuted(address indexed account)
func (_AcrossV3Adapter *AcrossV3AdapterFilterer) WatchAcrossFundsReceivedAndExecuted(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterAcrossFundsReceivedAndExecuted, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossV3Adapter.contract.WatchLogs(opts, "AcrossFundsReceivedAndExecuted", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterAcrossFundsReceivedAndExecuted)
				if err := _AcrossV3Adapter.contract.UnpackLog(event, "AcrossFundsReceivedAndExecuted", log); err != nil {
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
func (_AcrossV3Adapter *AcrossV3AdapterFilterer) ParseAcrossFundsReceivedAndExecuted(log types.Log) (*AcrossV3AdapterAcrossFundsReceivedAndExecuted, error) {
	event := new(AcrossV3AdapterAcrossFundsReceivedAndExecuted)
	if err := _AcrossV3Adapter.contract.UnpackLog(event, "AcrossFundsReceivedAndExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterAcrossFundsReceivedButExecutionFailedIterator is returned from FilterAcrossFundsReceivedButExecutionFailed and is used to iterate over the raw logs and unpacked data for AcrossFundsReceivedButExecutionFailed events raised by the AcrossV3Adapter contract.
type AcrossV3AdapterAcrossFundsReceivedButExecutionFailedIterator struct {
	Event *AcrossV3AdapterAcrossFundsReceivedButExecutionFailed // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterAcrossFundsReceivedButExecutionFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterAcrossFundsReceivedButExecutionFailed)
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
		it.Event = new(AcrossV3AdapterAcrossFundsReceivedButExecutionFailed)
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
func (it *AcrossV3AdapterAcrossFundsReceivedButExecutionFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterAcrossFundsReceivedButExecutionFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterAcrossFundsReceivedButExecutionFailed represents a AcrossFundsReceivedButExecutionFailed event raised by the AcrossV3Adapter contract.
type AcrossV3AdapterAcrossFundsReceivedButExecutionFailed struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAcrossFundsReceivedButExecutionFailed is a free log retrieval operation binding the contract event 0x04c138373117f58fea06058b5a537a58b5a5324f226667d219560baa728b609a.
//
// Solidity: event AcrossFundsReceivedButExecutionFailed(address indexed account)
func (_AcrossV3Adapter *AcrossV3AdapterFilterer) FilterAcrossFundsReceivedButExecutionFailed(opts *bind.FilterOpts, account []common.Address) (*AcrossV3AdapterAcrossFundsReceivedButExecutionFailedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossV3Adapter.contract.FilterLogs(opts, "AcrossFundsReceivedButExecutionFailed", accountRule)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterAcrossFundsReceivedButExecutionFailedIterator{contract: _AcrossV3Adapter.contract, event: "AcrossFundsReceivedButExecutionFailed", logs: logs, sub: sub}, nil
}

// WatchAcrossFundsReceivedButExecutionFailed is a free log subscription operation binding the contract event 0x04c138373117f58fea06058b5a537a58b5a5324f226667d219560baa728b609a.
//
// Solidity: event AcrossFundsReceivedButExecutionFailed(address indexed account)
func (_AcrossV3Adapter *AcrossV3AdapterFilterer) WatchAcrossFundsReceivedButExecutionFailed(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterAcrossFundsReceivedButExecutionFailed, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossV3Adapter.contract.WatchLogs(opts, "AcrossFundsReceivedButExecutionFailed", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterAcrossFundsReceivedButExecutionFailed)
				if err := _AcrossV3Adapter.contract.UnpackLog(event, "AcrossFundsReceivedButExecutionFailed", log); err != nil {
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
func (_AcrossV3Adapter *AcrossV3AdapterFilterer) ParseAcrossFundsReceivedButExecutionFailed(log types.Log) (*AcrossV3AdapterAcrossFundsReceivedButExecutionFailed, error) {
	event := new(AcrossV3AdapterAcrossFundsReceivedButExecutionFailed)
	if err := _AcrossV3Adapter.contract.UnpackLog(event, "AcrossFundsReceivedButExecutionFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterAcrossFundsReceivedButNotEnoughBalanceIterator is returned from FilterAcrossFundsReceivedButNotEnoughBalance and is used to iterate over the raw logs and unpacked data for AcrossFundsReceivedButNotEnoughBalance events raised by the AcrossV3Adapter contract.
type AcrossV3AdapterAcrossFundsReceivedButNotEnoughBalanceIterator struct {
	Event *AcrossV3AdapterAcrossFundsReceivedButNotEnoughBalance // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterAcrossFundsReceivedButNotEnoughBalanceIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterAcrossFundsReceivedButNotEnoughBalance)
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
		it.Event = new(AcrossV3AdapterAcrossFundsReceivedButNotEnoughBalance)
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
func (it *AcrossV3AdapterAcrossFundsReceivedButNotEnoughBalanceIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterAcrossFundsReceivedButNotEnoughBalanceIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterAcrossFundsReceivedButNotEnoughBalance represents a AcrossFundsReceivedButNotEnoughBalance event raised by the AcrossV3Adapter contract.
type AcrossV3AdapterAcrossFundsReceivedButNotEnoughBalance struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAcrossFundsReceivedButNotEnoughBalance is a free log retrieval operation binding the contract event 0xb86165879c164ced5021b2b5c5c559281e991c7171a39df5b2699f900a9f3ebe.
//
// Solidity: event AcrossFundsReceivedButNotEnoughBalance(address indexed account)
func (_AcrossV3Adapter *AcrossV3AdapterFilterer) FilterAcrossFundsReceivedButNotEnoughBalance(opts *bind.FilterOpts, account []common.Address) (*AcrossV3AdapterAcrossFundsReceivedButNotEnoughBalanceIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossV3Adapter.contract.FilterLogs(opts, "AcrossFundsReceivedButNotEnoughBalance", accountRule)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterAcrossFundsReceivedButNotEnoughBalanceIterator{contract: _AcrossV3Adapter.contract, event: "AcrossFundsReceivedButNotEnoughBalance", logs: logs, sub: sub}, nil
}

// WatchAcrossFundsReceivedButNotEnoughBalance is a free log subscription operation binding the contract event 0xb86165879c164ced5021b2b5c5c559281e991c7171a39df5b2699f900a9f3ebe.
//
// Solidity: event AcrossFundsReceivedButNotEnoughBalance(address indexed account)
func (_AcrossV3Adapter *AcrossV3AdapterFilterer) WatchAcrossFundsReceivedButNotEnoughBalance(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterAcrossFundsReceivedButNotEnoughBalance, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossV3Adapter.contract.WatchLogs(opts, "AcrossFundsReceivedButNotEnoughBalance", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterAcrossFundsReceivedButNotEnoughBalance)
				if err := _AcrossV3Adapter.contract.UnpackLog(event, "AcrossFundsReceivedButNotEnoughBalance", log); err != nil {
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
func (_AcrossV3Adapter *AcrossV3AdapterFilterer) ParseAcrossFundsReceivedButNotEnoughBalance(log types.Log) (*AcrossV3AdapterAcrossFundsReceivedButNotEnoughBalance, error) {
	event := new(AcrossV3AdapterAcrossFundsReceivedButNotEnoughBalance)
	if err := _AcrossV3Adapter.contract.UnpackLog(event, "AcrossFundsReceivedButNotEnoughBalance", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
