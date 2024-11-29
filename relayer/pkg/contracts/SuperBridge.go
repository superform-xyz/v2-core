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

// SuperBridgeMetaData contains all meta data concerning the SuperBridge contract.
var SuperBridgeMetaData = &bind.MetaData{
	ABI: "[{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_relayer\",\"type\":\"address\"}],\"stateMutability\":\"nonpayable\",\"type\":\"constructor\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"destinationChainId\",\"type\":\"uint256\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"destinationContract\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"bytes\",\"name\":\"data\",\"type\":\"bytes\"}],\"name\":\"Msg\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"destinationChainId\",\"type\":\"uint256\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"destinationContract\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"bytes\",\"name\":\"data\",\"type\":\"bytes\"}],\"name\":\"Pricer\",\"type\":\"event\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"dstChainId\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"addr\",\"type\":\"address\"}],\"name\":\"fetchPrice\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"relayer\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"addr\",\"type\":\"address\"},{\"internalType\":\"bytes\",\"name\":\"data\",\"type\":\"bytes\"}],\"name\":\"release\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"dstChainId\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"addr\",\"type\":\"address\"},{\"internalType\":\"bytes\",\"name\":\"data\",\"type\":\"bytes\"}],\"name\":\"send\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"}]",
}

// SuperBridgeABI is the input ABI used to generate the binding from.
// Deprecated: Use SuperBridgeMetaData.ABI instead.
var SuperBridgeABI = SuperBridgeMetaData.ABI

// SuperBridge is an auto generated Go binding around an Ethereum contract.
type SuperBridge struct {
	SuperBridgeCaller     // Read-only binding to the contract
	SuperBridgeTransactor // Write-only binding to the contract
	SuperBridgeFilterer   // Log filterer for contract events
}

// SuperBridgeCaller is an auto generated read-only Go binding around an Ethereum contract.
type SuperBridgeCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperBridgeTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SuperBridgeTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperBridgeFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SuperBridgeFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SuperBridgeSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SuperBridgeSession struct {
	Contract     *SuperBridge      // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// SuperBridgeCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SuperBridgeCallerSession struct {
	Contract *SuperBridgeCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts      // Call options to use throughout this session
}

// SuperBridgeTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SuperBridgeTransactorSession struct {
	Contract     *SuperBridgeTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts      // Transaction auth options to use throughout this session
}

// SuperBridgeRaw is an auto generated low-level Go binding around an Ethereum contract.
type SuperBridgeRaw struct {
	Contract *SuperBridge // Generic contract binding to access the raw methods on
}

// SuperBridgeCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SuperBridgeCallerRaw struct {
	Contract *SuperBridgeCaller // Generic read-only contract binding to access the raw methods on
}

// SuperBridgeTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SuperBridgeTransactorRaw struct {
	Contract *SuperBridgeTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSuperBridge creates a new instance of SuperBridge, bound to a specific deployed contract.
func NewSuperBridge(address common.Address, backend bind.ContractBackend) (*SuperBridge, error) {
	contract, err := bindSuperBridge(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SuperBridge{SuperBridgeCaller: SuperBridgeCaller{contract: contract}, SuperBridgeTransactor: SuperBridgeTransactor{contract: contract}, SuperBridgeFilterer: SuperBridgeFilterer{contract: contract}}, nil
}

// NewSuperBridgeCaller creates a new read-only instance of SuperBridge, bound to a specific deployed contract.
func NewSuperBridgeCaller(address common.Address, caller bind.ContractCaller) (*SuperBridgeCaller, error) {
	contract, err := bindSuperBridge(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SuperBridgeCaller{contract: contract}, nil
}

// NewSuperBridgeTransactor creates a new write-only instance of SuperBridge, bound to a specific deployed contract.
func NewSuperBridgeTransactor(address common.Address, transactor bind.ContractTransactor) (*SuperBridgeTransactor, error) {
	contract, err := bindSuperBridge(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SuperBridgeTransactor{contract: contract}, nil
}

// NewSuperBridgeFilterer creates a new log filterer instance of SuperBridge, bound to a specific deployed contract.
func NewSuperBridgeFilterer(address common.Address, filterer bind.ContractFilterer) (*SuperBridgeFilterer, error) {
	contract, err := bindSuperBridge(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SuperBridgeFilterer{contract: contract}, nil
}

// bindSuperBridge binds a generic wrapper to an already deployed contract.
func bindSuperBridge(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SuperBridgeMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperBridge *SuperBridgeRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperBridge.Contract.SuperBridgeCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperBridge *SuperBridgeRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperBridge.Contract.SuperBridgeTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperBridge *SuperBridgeRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperBridge.Contract.SuperBridgeTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SuperBridge *SuperBridgeCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SuperBridge.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SuperBridge *SuperBridgeTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SuperBridge.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SuperBridge *SuperBridgeTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SuperBridge.Contract.contract.Transact(opts, method, params...)
}

// Relayer is a free data retrieval call binding the contract method 0x8406c079.
//
// Solidity: function relayer() view returns(address)
func (_SuperBridge *SuperBridgeCaller) Relayer(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SuperBridge.contract.Call(opts, &out, "relayer")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Relayer is a free data retrieval call binding the contract method 0x8406c079.
//
// Solidity: function relayer() view returns(address)
func (_SuperBridge *SuperBridgeSession) Relayer() (common.Address, error) {
	return _SuperBridge.Contract.Relayer(&_SuperBridge.CallOpts)
}

// Relayer is a free data retrieval call binding the contract method 0x8406c079.
//
// Solidity: function relayer() view returns(address)
func (_SuperBridge *SuperBridgeCallerSession) Relayer() (common.Address, error) {
	return _SuperBridge.Contract.Relayer(&_SuperBridge.CallOpts)
}

// FetchPrice is a paid mutator transaction binding the contract method 0x831a6839.
//
// Solidity: function fetchPrice(uint256 dstChainId, address addr) returns()
func (_SuperBridge *SuperBridgeTransactor) FetchPrice(opts *bind.TransactOpts, dstChainId *big.Int, addr common.Address) (*types.Transaction, error) {
	return _SuperBridge.contract.Transact(opts, "fetchPrice", dstChainId, addr)
}

// FetchPrice is a paid mutator transaction binding the contract method 0x831a6839.
//
// Solidity: function fetchPrice(uint256 dstChainId, address addr) returns()
func (_SuperBridge *SuperBridgeSession) FetchPrice(dstChainId *big.Int, addr common.Address) (*types.Transaction, error) {
	return _SuperBridge.Contract.FetchPrice(&_SuperBridge.TransactOpts, dstChainId, addr)
}

// FetchPrice is a paid mutator transaction binding the contract method 0x831a6839.
//
// Solidity: function fetchPrice(uint256 dstChainId, address addr) returns()
func (_SuperBridge *SuperBridgeTransactorSession) FetchPrice(dstChainId *big.Int, addr common.Address) (*types.Transaction, error) {
	return _SuperBridge.Contract.FetchPrice(&_SuperBridge.TransactOpts, dstChainId, addr)
}

// Release is a paid mutator transaction binding the contract method 0xaf411b1d.
//
// Solidity: function release(address addr, bytes data) returns()
func (_SuperBridge *SuperBridgeTransactor) Release(opts *bind.TransactOpts, addr common.Address, data []byte) (*types.Transaction, error) {
	return _SuperBridge.contract.Transact(opts, "release", addr, data)
}

// Release is a paid mutator transaction binding the contract method 0xaf411b1d.
//
// Solidity: function release(address addr, bytes data) returns()
func (_SuperBridge *SuperBridgeSession) Release(addr common.Address, data []byte) (*types.Transaction, error) {
	return _SuperBridge.Contract.Release(&_SuperBridge.TransactOpts, addr, data)
}

// Release is a paid mutator transaction binding the contract method 0xaf411b1d.
//
// Solidity: function release(address addr, bytes data) returns()
func (_SuperBridge *SuperBridgeTransactorSession) Release(addr common.Address, data []byte) (*types.Transaction, error) {
	return _SuperBridge.Contract.Release(&_SuperBridge.TransactOpts, addr, data)
}

// Send is a paid mutator transaction binding the contract method 0x150b375f.
//
// Solidity: function send(uint256 dstChainId, address addr, bytes data) returns()
func (_SuperBridge *SuperBridgeTransactor) Send(opts *bind.TransactOpts, dstChainId *big.Int, addr common.Address, data []byte) (*types.Transaction, error) {
	return _SuperBridge.contract.Transact(opts, "send", dstChainId, addr, data)
}

// Send is a paid mutator transaction binding the contract method 0x150b375f.
//
// Solidity: function send(uint256 dstChainId, address addr, bytes data) returns()
func (_SuperBridge *SuperBridgeSession) Send(dstChainId *big.Int, addr common.Address, data []byte) (*types.Transaction, error) {
	return _SuperBridge.Contract.Send(&_SuperBridge.TransactOpts, dstChainId, addr, data)
}

// Send is a paid mutator transaction binding the contract method 0x150b375f.
//
// Solidity: function send(uint256 dstChainId, address addr, bytes data) returns()
func (_SuperBridge *SuperBridgeTransactorSession) Send(dstChainId *big.Int, addr common.Address, data []byte) (*types.Transaction, error) {
	return _SuperBridge.Contract.Send(&_SuperBridge.TransactOpts, dstChainId, addr, data)
}

// SuperBridgeMsgIterator is returned from FilterMsg and is used to iterate over the raw logs and unpacked data for Msg events raised by the SuperBridge contract.
type SuperBridgeMsgIterator struct {
	Event *SuperBridgeMsg // Event containing the contract specifics and raw log

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
func (it *SuperBridgeMsgIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperBridgeMsg)
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
		it.Event = new(SuperBridgeMsg)
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
func (it *SuperBridgeMsgIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperBridgeMsgIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperBridgeMsg represents a Msg event raised by the SuperBridge contract.
type SuperBridgeMsg struct {
	DestinationChainId  *big.Int
	DestinationContract common.Address
	Data                []byte
	Raw                 types.Log // Blockchain specific contextual infos
}

// FilterMsg is a free log retrieval operation binding the contract event 0x48e957ce415904e13d24866d8154cae4d6effcae2b4676dab6c58ec19258c262.
//
// Solidity: event Msg(uint256 indexed destinationChainId, address indexed destinationContract, bytes data)
func (_SuperBridge *SuperBridgeFilterer) FilterMsg(opts *bind.FilterOpts, destinationChainId []*big.Int, destinationContract []common.Address) (*SuperBridgeMsgIterator, error) {

	var destinationChainIdRule []interface{}
	for _, destinationChainIdItem := range destinationChainId {
		destinationChainIdRule = append(destinationChainIdRule, destinationChainIdItem)
	}
	var destinationContractRule []interface{}
	for _, destinationContractItem := range destinationContract {
		destinationContractRule = append(destinationContractRule, destinationContractItem)
	}

	logs, sub, err := _SuperBridge.contract.FilterLogs(opts, "Msg", destinationChainIdRule, destinationContractRule)
	if err != nil {
		return nil, err
	}
	return &SuperBridgeMsgIterator{contract: _SuperBridge.contract, event: "Msg", logs: logs, sub: sub}, nil
}

// WatchMsg is a free log subscription operation binding the contract event 0x48e957ce415904e13d24866d8154cae4d6effcae2b4676dab6c58ec19258c262.
//
// Solidity: event Msg(uint256 indexed destinationChainId, address indexed destinationContract, bytes data)
func (_SuperBridge *SuperBridgeFilterer) WatchMsg(opts *bind.WatchOpts, sink chan<- *SuperBridgeMsg, destinationChainId []*big.Int, destinationContract []common.Address) (event.Subscription, error) {

	var destinationChainIdRule []interface{}
	for _, destinationChainIdItem := range destinationChainId {
		destinationChainIdRule = append(destinationChainIdRule, destinationChainIdItem)
	}
	var destinationContractRule []interface{}
	for _, destinationContractItem := range destinationContract {
		destinationContractRule = append(destinationContractRule, destinationContractItem)
	}

	logs, sub, err := _SuperBridge.contract.WatchLogs(opts, "Msg", destinationChainIdRule, destinationContractRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperBridgeMsg)
				if err := _SuperBridge.contract.UnpackLog(event, "Msg", log); err != nil {
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

// ParseMsg is a log parse operation binding the contract event 0x48e957ce415904e13d24866d8154cae4d6effcae2b4676dab6c58ec19258c262.
//
// Solidity: event Msg(uint256 indexed destinationChainId, address indexed destinationContract, bytes data)
func (_SuperBridge *SuperBridgeFilterer) ParseMsg(log types.Log) (*SuperBridgeMsg, error) {
	event := new(SuperBridgeMsg)
	if err := _SuperBridge.contract.UnpackLog(event, "Msg", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SuperBridgePricerIterator is returned from FilterPricer and is used to iterate over the raw logs and unpacked data for Pricer events raised by the SuperBridge contract.
type SuperBridgePricerIterator struct {
	Event *SuperBridgePricer // Event containing the contract specifics and raw log

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
func (it *SuperBridgePricerIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SuperBridgePricer)
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
		it.Event = new(SuperBridgePricer)
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
func (it *SuperBridgePricerIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SuperBridgePricerIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SuperBridgePricer represents a Pricer event raised by the SuperBridge contract.
type SuperBridgePricer struct {
	DestinationChainId  *big.Int
	DestinationContract common.Address
	Data                []byte
	Raw                 types.Log // Blockchain specific contextual infos
}

// FilterPricer is a free log retrieval operation binding the contract event 0x3dad79e8b0ebc64e0dbce0cee3d781072c1afdbae17f98f9031338708a957fe5.
//
// Solidity: event Pricer(uint256 indexed destinationChainId, address indexed destinationContract, bytes data)
func (_SuperBridge *SuperBridgeFilterer) FilterPricer(opts *bind.FilterOpts, destinationChainId []*big.Int, destinationContract []common.Address) (*SuperBridgePricerIterator, error) {

	var destinationChainIdRule []interface{}
	for _, destinationChainIdItem := range destinationChainId {
		destinationChainIdRule = append(destinationChainIdRule, destinationChainIdItem)
	}
	var destinationContractRule []interface{}
	for _, destinationContractItem := range destinationContract {
		destinationContractRule = append(destinationContractRule, destinationContractItem)
	}

	logs, sub, err := _SuperBridge.contract.FilterLogs(opts, "Pricer", destinationChainIdRule, destinationContractRule)
	if err != nil {
		return nil, err
	}
	return &SuperBridgePricerIterator{contract: _SuperBridge.contract, event: "Pricer", logs: logs, sub: sub}, nil
}

// WatchPricer is a free log subscription operation binding the contract event 0x3dad79e8b0ebc64e0dbce0cee3d781072c1afdbae17f98f9031338708a957fe5.
//
// Solidity: event Pricer(uint256 indexed destinationChainId, address indexed destinationContract, bytes data)
func (_SuperBridge *SuperBridgeFilterer) WatchPricer(opts *bind.WatchOpts, sink chan<- *SuperBridgePricer, destinationChainId []*big.Int, destinationContract []common.Address) (event.Subscription, error) {

	var destinationChainIdRule []interface{}
	for _, destinationChainIdItem := range destinationChainId {
		destinationChainIdRule = append(destinationChainIdRule, destinationChainIdItem)
	}
	var destinationContractRule []interface{}
	for _, destinationContractItem := range destinationContract {
		destinationContractRule = append(destinationContractRule, destinationContractItem)
	}

	logs, sub, err := _SuperBridge.contract.WatchLogs(opts, "Pricer", destinationChainIdRule, destinationContractRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SuperBridgePricer)
				if err := _SuperBridge.contract.UnpackLog(event, "Pricer", log); err != nil {
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

// ParsePricer is a log parse operation binding the contract event 0x3dad79e8b0ebc64e0dbce0cee3d781072c1afdbae17f98f9031338708a957fe5.
//
// Solidity: event Pricer(uint256 indexed destinationChainId, address indexed destinationContract, bytes data)
func (_SuperBridge *SuperBridgeFilterer) ParsePricer(log types.Log) (*SuperBridgePricer, error) {
	event := new(SuperBridgePricer)
	if err := _SuperBridge.contract.UnpackLog(event, "Pricer", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
