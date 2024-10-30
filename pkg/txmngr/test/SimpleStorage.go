// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package test

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

// SimpleStorageMetaData contains all meta data concerning the SimpleStorage contract.
var SimpleStorageMetaData = &bind.MetaData{
	ABI: "[{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"data\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"sender\",\"type\":\"address\"}],\"name\":\"DataAdded\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"data\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"sender\",\"type\":\"address\"}],\"name\":\"DataStored\",\"type\":\"event\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"x\",\"type\":\"uint256\"}],\"name\":\"add\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"get\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"x\",\"type\":\"uint256\"}],\"name\":\"set\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"storedData\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"}]",
	Bin: "0x608060405234801561001057600080fd5b506102fc806100206000396000f3fe608060405234801561001057600080fd5b506004361061004c5760003560e01c80631003e2d2146100515780632a1afcd91461006d57806360fe47b11461008b5780636d4ce63c146100a7575b600080fd5b61006b600480360381019061006691906101a2565b6100c5565b005b610075610115565b60405161008291906101de565b60405180910390f35b6100a560048036038101906100a091906101a2565b61011b565b005b6100af61015e565b6040516100bc91906101de565b60405180910390f35b806000546100d39190610228565b6000819055507f82b592fada6dcac03266e40654e46dd863694b963f89fdb25267910b38f6ae43813360405161010a92919061029d565b60405180910390a150565b60005481565b806000819055507fad78bd60223e723bf7bdc74c7dfda6b62da93a84d5765178bc8a8ec6a365376e813360405161015392919061029d565b60405180910390a150565b60008054905090565b600080fd5b6000819050919050565b61017f8161016c565b811461018a57600080fd5b50565b60008135905061019c81610176565b92915050565b6000602082840312156101b8576101b7610167565b5b60006101c68482850161018d565b91505092915050565b6101d88161016c565b82525050565b60006020820190506101f360008301846101cf565b92915050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b60006102338261016c565b915061023e8361016c565b9250828201905080821115610256576102556101f9565b5b92915050565b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b60006102878261025c565b9050919050565b6102978161027c565b82525050565b60006040820190506102b260008301856101cf565b6102bf602083018461028e565b939250505056fea26469706673582212208a1c1405becd44f08a94e5606363e895de9017694a5b58bea366da5122829a2464736f6c63430008130033",
}

// SimpleStorageABI is the input ABI used to generate the binding from.
// Deprecated: Use SimpleStorageMetaData.ABI instead.
var SimpleStorageABI = SimpleStorageMetaData.ABI

// SimpleStorageBin is the compiled bytecode used for deploying new contracts.
// Deprecated: Use SimpleStorageMetaData.Bin instead.
var SimpleStorageBin = SimpleStorageMetaData.Bin

// DeploySimpleStorage deploys a new Ethereum contract, binding an instance of SimpleStorage to it.
func DeploySimpleStorage(auth *bind.TransactOpts, backend bind.ContractBackend) (common.Address, *types.Transaction, *SimpleStorage, error) {
	parsed, err := SimpleStorageMetaData.GetAbi()
	if err != nil {
		return common.Address{}, nil, nil, err
	}
	if parsed == nil {
		return common.Address{}, nil, nil, errors.New("GetABI returned nil")
	}

	address, tx, contract, err := bind.DeployContract(auth, *parsed, common.FromHex(SimpleStorageBin), backend)
	if err != nil {
		return common.Address{}, nil, nil, err
	}
	return address, tx, &SimpleStorage{SimpleStorageCaller: SimpleStorageCaller{contract: contract}, SimpleStorageTransactor: SimpleStorageTransactor{contract: contract}, SimpleStorageFilterer: SimpleStorageFilterer{contract: contract}}, nil
}

// SimpleStorage is an auto generated Go binding around an Ethereum contract.
type SimpleStorage struct {
	SimpleStorageCaller     // Read-only binding to the contract
	SimpleStorageTransactor // Write-only binding to the contract
	SimpleStorageFilterer   // Log filterer for contract events
}

// SimpleStorageCaller is an auto generated read-only Go binding around an Ethereum contract.
type SimpleStorageCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SimpleStorageTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SimpleStorageTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SimpleStorageFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SimpleStorageFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SimpleStorageSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SimpleStorageSession struct {
	Contract     *SimpleStorage    // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// SimpleStorageCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SimpleStorageCallerSession struct {
	Contract *SimpleStorageCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts        // Call options to use throughout this session
}

// SimpleStorageTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SimpleStorageTransactorSession struct {
	Contract     *SimpleStorageTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts        // Transaction auth options to use throughout this session
}

// SimpleStorageRaw is an auto generated low-level Go binding around an Ethereum contract.
type SimpleStorageRaw struct {
	Contract *SimpleStorage // Generic contract binding to access the raw methods on
}

// SimpleStorageCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SimpleStorageCallerRaw struct {
	Contract *SimpleStorageCaller // Generic read-only contract binding to access the raw methods on
}

// SimpleStorageTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SimpleStorageTransactorRaw struct {
	Contract *SimpleStorageTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSimpleStorage creates a new instance of SimpleStorage, bound to a specific deployed contract.
func NewSimpleStorage(address common.Address, backend bind.ContractBackend) (*SimpleStorage, error) {
	contract, err := bindSimpleStorage(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SimpleStorage{SimpleStorageCaller: SimpleStorageCaller{contract: contract}, SimpleStorageTransactor: SimpleStorageTransactor{contract: contract}, SimpleStorageFilterer: SimpleStorageFilterer{contract: contract}}, nil
}

// NewSimpleStorageCaller creates a new read-only instance of SimpleStorage, bound to a specific deployed contract.
func NewSimpleStorageCaller(address common.Address, caller bind.ContractCaller) (*SimpleStorageCaller, error) {
	contract, err := bindSimpleStorage(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SimpleStorageCaller{contract: contract}, nil
}

// NewSimpleStorageTransactor creates a new write-only instance of SimpleStorage, bound to a specific deployed contract.
func NewSimpleStorageTransactor(address common.Address, transactor bind.ContractTransactor) (*SimpleStorageTransactor, error) {
	contract, err := bindSimpleStorage(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SimpleStorageTransactor{contract: contract}, nil
}

// NewSimpleStorageFilterer creates a new log filterer instance of SimpleStorage, bound to a specific deployed contract.
func NewSimpleStorageFilterer(address common.Address, filterer bind.ContractFilterer) (*SimpleStorageFilterer, error) {
	contract, err := bindSimpleStorage(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SimpleStorageFilterer{contract: contract}, nil
}

// bindSimpleStorage binds a generic wrapper to an already deployed contract.
func bindSimpleStorage(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SimpleStorageMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SimpleStorage *SimpleStorageRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SimpleStorage.Contract.SimpleStorageCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SimpleStorage *SimpleStorageRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SimpleStorage.Contract.SimpleStorageTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SimpleStorage *SimpleStorageRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SimpleStorage.Contract.SimpleStorageTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SimpleStorage *SimpleStorageCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SimpleStorage.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SimpleStorage *SimpleStorageTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SimpleStorage.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SimpleStorage *SimpleStorageTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SimpleStorage.Contract.contract.Transact(opts, method, params...)
}

// Get is a free data retrieval call binding the contract method 0x6d4ce63c.
//
// Solidity: function get() view returns(uint256)
func (_SimpleStorage *SimpleStorageCaller) Get(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SimpleStorage.contract.Call(opts, &out, "get")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// Get is a free data retrieval call binding the contract method 0x6d4ce63c.
//
// Solidity: function get() view returns(uint256)
func (_SimpleStorage *SimpleStorageSession) Get() (*big.Int, error) {
	return _SimpleStorage.Contract.Get(&_SimpleStorage.CallOpts)
}

// Get is a free data retrieval call binding the contract method 0x6d4ce63c.
//
// Solidity: function get() view returns(uint256)
func (_SimpleStorage *SimpleStorageCallerSession) Get() (*big.Int, error) {
	return _SimpleStorage.Contract.Get(&_SimpleStorage.CallOpts)
}

// StoredData is a free data retrieval call binding the contract method 0x2a1afcd9.
//
// Solidity: function storedData() view returns(uint256)
func (_SimpleStorage *SimpleStorageCaller) StoredData(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SimpleStorage.contract.Call(opts, &out, "storedData")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// StoredData is a free data retrieval call binding the contract method 0x2a1afcd9.
//
// Solidity: function storedData() view returns(uint256)
func (_SimpleStorage *SimpleStorageSession) StoredData() (*big.Int, error) {
	return _SimpleStorage.Contract.StoredData(&_SimpleStorage.CallOpts)
}

// StoredData is a free data retrieval call binding the contract method 0x2a1afcd9.
//
// Solidity: function storedData() view returns(uint256)
func (_SimpleStorage *SimpleStorageCallerSession) StoredData() (*big.Int, error) {
	return _SimpleStorage.Contract.StoredData(&_SimpleStorage.CallOpts)
}

// Add is a paid mutator transaction binding the contract method 0x1003e2d2.
//
// Solidity: function add(uint256 x) returns()
func (_SimpleStorage *SimpleStorageTransactor) Add(opts *bind.TransactOpts, x *big.Int) (*types.Transaction, error) {
	return _SimpleStorage.contract.Transact(opts, "add", x)
}

// Add is a paid mutator transaction binding the contract method 0x1003e2d2.
//
// Solidity: function add(uint256 x) returns()
func (_SimpleStorage *SimpleStorageSession) Add(x *big.Int) (*types.Transaction, error) {
	return _SimpleStorage.Contract.Add(&_SimpleStorage.TransactOpts, x)
}

// Add is a paid mutator transaction binding the contract method 0x1003e2d2.
//
// Solidity: function add(uint256 x) returns()
func (_SimpleStorage *SimpleStorageTransactorSession) Add(x *big.Int) (*types.Transaction, error) {
	return _SimpleStorage.Contract.Add(&_SimpleStorage.TransactOpts, x)
}

// Set is a paid mutator transaction binding the contract method 0x60fe47b1.
//
// Solidity: function set(uint256 x) returns()
func (_SimpleStorage *SimpleStorageTransactor) Set(opts *bind.TransactOpts, x *big.Int) (*types.Transaction, error) {
	return _SimpleStorage.contract.Transact(opts, "set", x)
}

// Set is a paid mutator transaction binding the contract method 0x60fe47b1.
//
// Solidity: function set(uint256 x) returns()
func (_SimpleStorage *SimpleStorageSession) Set(x *big.Int) (*types.Transaction, error) {
	return _SimpleStorage.Contract.Set(&_SimpleStorage.TransactOpts, x)
}

// Set is a paid mutator transaction binding the contract method 0x60fe47b1.
//
// Solidity: function set(uint256 x) returns()
func (_SimpleStorage *SimpleStorageTransactorSession) Set(x *big.Int) (*types.Transaction, error) {
	return _SimpleStorage.Contract.Set(&_SimpleStorage.TransactOpts, x)
}

// SimpleStorageDataAddedIterator is returned from FilterDataAdded and is used to iterate over the raw logs and unpacked data for DataAdded events raised by the SimpleStorage contract.
type SimpleStorageDataAddedIterator struct {
	Event *SimpleStorageDataAdded // Event containing the contract specifics and raw log

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
func (it *SimpleStorageDataAddedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SimpleStorageDataAdded)
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
		it.Event = new(SimpleStorageDataAdded)
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
func (it *SimpleStorageDataAddedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SimpleStorageDataAddedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SimpleStorageDataAdded represents a DataAdded event raised by the SimpleStorage contract.
type SimpleStorageDataAdded struct {
	Data   *big.Int
	Sender common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterDataAdded is a free log retrieval operation binding the contract event 0x82b592fada6dcac03266e40654e46dd863694b963f89fdb25267910b38f6ae43.
//
// Solidity: event DataAdded(uint256 data, address sender)
func (_SimpleStorage *SimpleStorageFilterer) FilterDataAdded(opts *bind.FilterOpts) (*SimpleStorageDataAddedIterator, error) {

	logs, sub, err := _SimpleStorage.contract.FilterLogs(opts, "DataAdded")
	if err != nil {
		return nil, err
	}
	return &SimpleStorageDataAddedIterator{contract: _SimpleStorage.contract, event: "DataAdded", logs: logs, sub: sub}, nil
}

// WatchDataAdded is a free log subscription operation binding the contract event 0x82b592fada6dcac03266e40654e46dd863694b963f89fdb25267910b38f6ae43.
//
// Solidity: event DataAdded(uint256 data, address sender)
func (_SimpleStorage *SimpleStorageFilterer) WatchDataAdded(opts *bind.WatchOpts, sink chan<- *SimpleStorageDataAdded) (event.Subscription, error) {

	logs, sub, err := _SimpleStorage.contract.WatchLogs(opts, "DataAdded")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SimpleStorageDataAdded)
				if err := _SimpleStorage.contract.UnpackLog(event, "DataAdded", log); err != nil {
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

// ParseDataAdded is a log parse operation binding the contract event 0x82b592fada6dcac03266e40654e46dd863694b963f89fdb25267910b38f6ae43.
//
// Solidity: event DataAdded(uint256 data, address sender)
func (_SimpleStorage *SimpleStorageFilterer) ParseDataAdded(log types.Log) (*SimpleStorageDataAdded, error) {
	event := new(SimpleStorageDataAdded)
	if err := _SimpleStorage.contract.UnpackLog(event, "DataAdded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SimpleStorageDataStoredIterator is returned from FilterDataStored and is used to iterate over the raw logs and unpacked data for DataStored events raised by the SimpleStorage contract.
type SimpleStorageDataStoredIterator struct {
	Event *SimpleStorageDataStored // Event containing the contract specifics and raw log

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
func (it *SimpleStorageDataStoredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SimpleStorageDataStored)
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
		it.Event = new(SimpleStorageDataStored)
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
func (it *SimpleStorageDataStoredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SimpleStorageDataStoredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SimpleStorageDataStored represents a DataStored event raised by the SimpleStorage contract.
type SimpleStorageDataStored struct {
	Data   *big.Int
	Sender common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterDataStored is a free log retrieval operation binding the contract event 0xad78bd60223e723bf7bdc74c7dfda6b62da93a84d5765178bc8a8ec6a365376e.
//
// Solidity: event DataStored(uint256 data, address sender)
func (_SimpleStorage *SimpleStorageFilterer) FilterDataStored(opts *bind.FilterOpts) (*SimpleStorageDataStoredIterator, error) {

	logs, sub, err := _SimpleStorage.contract.FilterLogs(opts, "DataStored")
	if err != nil {
		return nil, err
	}
	return &SimpleStorageDataStoredIterator{contract: _SimpleStorage.contract, event: "DataStored", logs: logs, sub: sub}, nil
}

// WatchDataStored is a free log subscription operation binding the contract event 0xad78bd60223e723bf7bdc74c7dfda6b62da93a84d5765178bc8a8ec6a365376e.
//
// Solidity: event DataStored(uint256 data, address sender)
func (_SimpleStorage *SimpleStorageFilterer) WatchDataStored(opts *bind.WatchOpts, sink chan<- *SimpleStorageDataStored) (event.Subscription, error) {

	logs, sub, err := _SimpleStorage.contract.WatchLogs(opts, "DataStored")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SimpleStorageDataStored)
				if err := _SimpleStorage.contract.UnpackLog(event, "DataStored", log); err != nil {
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

// ParseDataStored is a log parse operation binding the contract event 0xad78bd60223e723bf7bdc74c7dfda6b62da93a84d5765178bc8a8ec6a365376e.
//
// Solidity: event DataStored(uint256 data, address sender)
func (_SimpleStorage *SimpleStorageFilterer) ParseDataStored(log types.Log) (*SimpleStorageDataStored, error) {
	event := new(SimpleStorageDataStored)
	if err := _SimpleStorage.contract.UnpackLog(event, "DataStored", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
