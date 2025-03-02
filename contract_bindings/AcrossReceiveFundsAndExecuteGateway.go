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

// AcrossReceiveFundsAndExecuteGatewayMetaData contains all meta data concerning the AcrossReceiveFundsAndExecuteGateway contract.
var AcrossReceiveFundsAndExecuteGatewayMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"acrossSpokePool_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"entryPointAddress_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"superBundler_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"acrossSpokePool\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"entryPointAddress\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"handleV3AcrossMessage\",\"inputs\":[{\"name\":\"tokenSent\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"message\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"superBundler\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"addresspayable\"}],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"AcrossFundsReceivedAndExecuted\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AcrossFundsReceivedButNotEnoughBalance\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_SENDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SafeERC20FailedOperation\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}]}]",
}

// AcrossReceiveFundsAndExecuteGatewayABI is the input ABI used to generate the binding from.
// Deprecated: Use AcrossReceiveFundsAndExecuteGatewayMetaData.ABI instead.
var AcrossReceiveFundsAndExecuteGatewayABI = AcrossReceiveFundsAndExecuteGatewayMetaData.ABI

// AcrossReceiveFundsAndExecuteGateway is an auto generated Go binding around an Ethereum contract.
type AcrossReceiveFundsAndExecuteGateway struct {
	AcrossReceiveFundsAndExecuteGatewayCaller     // Read-only binding to the contract
	AcrossReceiveFundsAndExecuteGatewayTransactor // Write-only binding to the contract
	AcrossReceiveFundsAndExecuteGatewayFilterer   // Log filterer for contract events
}

// AcrossReceiveFundsAndExecuteGatewayCaller is an auto generated read-only Go binding around an Ethereum contract.
type AcrossReceiveFundsAndExecuteGatewayCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AcrossReceiveFundsAndExecuteGatewayTransactor is an auto generated write-only Go binding around an Ethereum contract.
type AcrossReceiveFundsAndExecuteGatewayTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AcrossReceiveFundsAndExecuteGatewayFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type AcrossReceiveFundsAndExecuteGatewayFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AcrossReceiveFundsAndExecuteGatewaySession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type AcrossReceiveFundsAndExecuteGatewaySession struct {
	Contract     *AcrossReceiveFundsAndExecuteGateway // Generic contract binding to set the session for
	CallOpts     bind.CallOpts                        // Call options to use throughout this session
	TransactOpts bind.TransactOpts                    // Transaction auth options to use throughout this session
}

// AcrossReceiveFundsAndExecuteGatewayCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type AcrossReceiveFundsAndExecuteGatewayCallerSession struct {
	Contract *AcrossReceiveFundsAndExecuteGatewayCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                              // Call options to use throughout this session
}

// AcrossReceiveFundsAndExecuteGatewayTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type AcrossReceiveFundsAndExecuteGatewayTransactorSession struct {
	Contract     *AcrossReceiveFundsAndExecuteGatewayTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                              // Transaction auth options to use throughout this session
}

// AcrossReceiveFundsAndExecuteGatewayRaw is an auto generated low-level Go binding around an Ethereum contract.
type AcrossReceiveFundsAndExecuteGatewayRaw struct {
	Contract *AcrossReceiveFundsAndExecuteGateway // Generic contract binding to access the raw methods on
}

// AcrossReceiveFundsAndExecuteGatewayCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type AcrossReceiveFundsAndExecuteGatewayCallerRaw struct {
	Contract *AcrossReceiveFundsAndExecuteGatewayCaller // Generic read-only contract binding to access the raw methods on
}

// AcrossReceiveFundsAndExecuteGatewayTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type AcrossReceiveFundsAndExecuteGatewayTransactorRaw struct {
	Contract *AcrossReceiveFundsAndExecuteGatewayTransactor // Generic write-only contract binding to access the raw methods on
}

// NewAcrossReceiveFundsAndExecuteGateway creates a new instance of AcrossReceiveFundsAndExecuteGateway, bound to a specific deployed contract.
func NewAcrossReceiveFundsAndExecuteGateway(address common.Address, backend bind.ContractBackend) (*AcrossReceiveFundsAndExecuteGateway, error) {
	contract, err := bindAcrossReceiveFundsAndExecuteGateway(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &AcrossReceiveFundsAndExecuteGateway{AcrossReceiveFundsAndExecuteGatewayCaller: AcrossReceiveFundsAndExecuteGatewayCaller{contract: contract}, AcrossReceiveFundsAndExecuteGatewayTransactor: AcrossReceiveFundsAndExecuteGatewayTransactor{contract: contract}, AcrossReceiveFundsAndExecuteGatewayFilterer: AcrossReceiveFundsAndExecuteGatewayFilterer{contract: contract}}, nil
}

// NewAcrossReceiveFundsAndExecuteGatewayCaller creates a new read-only instance of AcrossReceiveFundsAndExecuteGateway, bound to a specific deployed contract.
func NewAcrossReceiveFundsAndExecuteGatewayCaller(address common.Address, caller bind.ContractCaller) (*AcrossReceiveFundsAndExecuteGatewayCaller, error) {
	contract, err := bindAcrossReceiveFundsAndExecuteGateway(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &AcrossReceiveFundsAndExecuteGatewayCaller{contract: contract}, nil
}

// NewAcrossReceiveFundsAndExecuteGatewayTransactor creates a new write-only instance of AcrossReceiveFundsAndExecuteGateway, bound to a specific deployed contract.
func NewAcrossReceiveFundsAndExecuteGatewayTransactor(address common.Address, transactor bind.ContractTransactor) (*AcrossReceiveFundsAndExecuteGatewayTransactor, error) {
	contract, err := bindAcrossReceiveFundsAndExecuteGateway(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &AcrossReceiveFundsAndExecuteGatewayTransactor{contract: contract}, nil
}

// NewAcrossReceiveFundsAndExecuteGatewayFilterer creates a new log filterer instance of AcrossReceiveFundsAndExecuteGateway, bound to a specific deployed contract.
func NewAcrossReceiveFundsAndExecuteGatewayFilterer(address common.Address, filterer bind.ContractFilterer) (*AcrossReceiveFundsAndExecuteGatewayFilterer, error) {
	contract, err := bindAcrossReceiveFundsAndExecuteGateway(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &AcrossReceiveFundsAndExecuteGatewayFilterer{contract: contract}, nil
}

// bindAcrossReceiveFundsAndExecuteGateway binds a generic wrapper to an already deployed contract.
func bindAcrossReceiveFundsAndExecuteGateway(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := AcrossReceiveFundsAndExecuteGatewayMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_AcrossReceiveFundsAndExecuteGateway *AcrossReceiveFundsAndExecuteGatewayRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _AcrossReceiveFundsAndExecuteGateway.Contract.AcrossReceiveFundsAndExecuteGatewayCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_AcrossReceiveFundsAndExecuteGateway *AcrossReceiveFundsAndExecuteGatewayRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossReceiveFundsAndExecuteGateway.Contract.AcrossReceiveFundsAndExecuteGatewayTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_AcrossReceiveFundsAndExecuteGateway *AcrossReceiveFundsAndExecuteGatewayRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _AcrossReceiveFundsAndExecuteGateway.Contract.AcrossReceiveFundsAndExecuteGatewayTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_AcrossReceiveFundsAndExecuteGateway *AcrossReceiveFundsAndExecuteGatewayCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _AcrossReceiveFundsAndExecuteGateway.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_AcrossReceiveFundsAndExecuteGateway *AcrossReceiveFundsAndExecuteGatewayTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossReceiveFundsAndExecuteGateway.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_AcrossReceiveFundsAndExecuteGateway *AcrossReceiveFundsAndExecuteGatewayTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _AcrossReceiveFundsAndExecuteGateway.Contract.contract.Transact(opts, method, params...)
}

// AcrossSpokePool is a free data retrieval call binding the contract method 0x063820da.
//
// Solidity: function acrossSpokePool() view returns(address)
func (_AcrossReceiveFundsAndExecuteGateway *AcrossReceiveFundsAndExecuteGatewayCaller) AcrossSpokePool(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossReceiveFundsAndExecuteGateway.contract.Call(opts, &out, "acrossSpokePool")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AcrossSpokePool is a free data retrieval call binding the contract method 0x063820da.
//
// Solidity: function acrossSpokePool() view returns(address)
func (_AcrossReceiveFundsAndExecuteGateway *AcrossReceiveFundsAndExecuteGatewaySession) AcrossSpokePool() (common.Address, error) {
	return _AcrossReceiveFundsAndExecuteGateway.Contract.AcrossSpokePool(&_AcrossReceiveFundsAndExecuteGateway.CallOpts)
}

// AcrossSpokePool is a free data retrieval call binding the contract method 0x063820da.
//
// Solidity: function acrossSpokePool() view returns(address)
func (_AcrossReceiveFundsAndExecuteGateway *AcrossReceiveFundsAndExecuteGatewayCallerSession) AcrossSpokePool() (common.Address, error) {
	return _AcrossReceiveFundsAndExecuteGateway.Contract.AcrossSpokePool(&_AcrossReceiveFundsAndExecuteGateway.CallOpts)
}

// EntryPointAddress is a free data retrieval call binding the contract method 0x06dc245c.
//
// Solidity: function entryPointAddress() view returns(address)
func (_AcrossReceiveFundsAndExecuteGateway *AcrossReceiveFundsAndExecuteGatewayCaller) EntryPointAddress(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossReceiveFundsAndExecuteGateway.contract.Call(opts, &out, "entryPointAddress")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// EntryPointAddress is a free data retrieval call binding the contract method 0x06dc245c.
//
// Solidity: function entryPointAddress() view returns(address)
func (_AcrossReceiveFundsAndExecuteGateway *AcrossReceiveFundsAndExecuteGatewaySession) EntryPointAddress() (common.Address, error) {
	return _AcrossReceiveFundsAndExecuteGateway.Contract.EntryPointAddress(&_AcrossReceiveFundsAndExecuteGateway.CallOpts)
}

// EntryPointAddress is a free data retrieval call binding the contract method 0x06dc245c.
//
// Solidity: function entryPointAddress() view returns(address)
func (_AcrossReceiveFundsAndExecuteGateway *AcrossReceiveFundsAndExecuteGatewayCallerSession) EntryPointAddress() (common.Address, error) {
	return _AcrossReceiveFundsAndExecuteGateway.Contract.EntryPointAddress(&_AcrossReceiveFundsAndExecuteGateway.CallOpts)
}

// SuperBundler is a free data retrieval call binding the contract method 0x61aeefef.
//
// Solidity: function superBundler() view returns(address)
func (_AcrossReceiveFundsAndExecuteGateway *AcrossReceiveFundsAndExecuteGatewayCaller) SuperBundler(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossReceiveFundsAndExecuteGateway.contract.Call(opts, &out, "superBundler")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SuperBundler is a free data retrieval call binding the contract method 0x61aeefef.
//
// Solidity: function superBundler() view returns(address)
func (_AcrossReceiveFundsAndExecuteGateway *AcrossReceiveFundsAndExecuteGatewaySession) SuperBundler() (common.Address, error) {
	return _AcrossReceiveFundsAndExecuteGateway.Contract.SuperBundler(&_AcrossReceiveFundsAndExecuteGateway.CallOpts)
}

// SuperBundler is a free data retrieval call binding the contract method 0x61aeefef.
//
// Solidity: function superBundler() view returns(address)
func (_AcrossReceiveFundsAndExecuteGateway *AcrossReceiveFundsAndExecuteGatewayCallerSession) SuperBundler() (common.Address, error) {
	return _AcrossReceiveFundsAndExecuteGateway.Contract.SuperBundler(&_AcrossReceiveFundsAndExecuteGateway.CallOpts)
}

// HandleV3AcrossMessage is a paid mutator transaction binding the contract method 0x3a5be8cb.
//
// Solidity: function handleV3AcrossMessage(address tokenSent, uint256 amount, address , bytes message) returns()
func (_AcrossReceiveFundsAndExecuteGateway *AcrossReceiveFundsAndExecuteGatewayTransactor) HandleV3AcrossMessage(opts *bind.TransactOpts, tokenSent common.Address, amount *big.Int, arg2 common.Address, message []byte) (*types.Transaction, error) {
	return _AcrossReceiveFundsAndExecuteGateway.contract.Transact(opts, "handleV3AcrossMessage", tokenSent, amount, arg2, message)
}

// HandleV3AcrossMessage is a paid mutator transaction binding the contract method 0x3a5be8cb.
//
// Solidity: function handleV3AcrossMessage(address tokenSent, uint256 amount, address , bytes message) returns()
func (_AcrossReceiveFundsAndExecuteGateway *AcrossReceiveFundsAndExecuteGatewaySession) HandleV3AcrossMessage(tokenSent common.Address, amount *big.Int, arg2 common.Address, message []byte) (*types.Transaction, error) {
	return _AcrossReceiveFundsAndExecuteGateway.Contract.HandleV3AcrossMessage(&_AcrossReceiveFundsAndExecuteGateway.TransactOpts, tokenSent, amount, arg2, message)
}

// HandleV3AcrossMessage is a paid mutator transaction binding the contract method 0x3a5be8cb.
//
// Solidity: function handleV3AcrossMessage(address tokenSent, uint256 amount, address , bytes message) returns()
func (_AcrossReceiveFundsAndExecuteGateway *AcrossReceiveFundsAndExecuteGatewayTransactorSession) HandleV3AcrossMessage(tokenSent common.Address, amount *big.Int, arg2 common.Address, message []byte) (*types.Transaction, error) {
	return _AcrossReceiveFundsAndExecuteGateway.Contract.HandleV3AcrossMessage(&_AcrossReceiveFundsAndExecuteGateway.TransactOpts, tokenSent, amount, arg2, message)
}

// AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedAndExecutedIterator is returned from FilterAcrossFundsReceivedAndExecuted and is used to iterate over the raw logs and unpacked data for AcrossFundsReceivedAndExecuted events raised by the AcrossReceiveFundsAndExecuteGateway contract.
type AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedAndExecutedIterator struct {
	Event *AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedAndExecuted // Event containing the contract specifics and raw log

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
func (it *AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedAndExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedAndExecuted)
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
		it.Event = new(AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedAndExecuted)
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
func (it *AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedAndExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedAndExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedAndExecuted represents a AcrossFundsReceivedAndExecuted event raised by the AcrossReceiveFundsAndExecuteGateway contract.
type AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedAndExecuted struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAcrossFundsReceivedAndExecuted is a free log retrieval operation binding the contract event 0xd88a3ae4799f4e1c36d5e250d49c982bbcdc83d4ef55ed7fbfda5b201759e65f.
//
// Solidity: event AcrossFundsReceivedAndExecuted(address indexed account)
func (_AcrossReceiveFundsAndExecuteGateway *AcrossReceiveFundsAndExecuteGatewayFilterer) FilterAcrossFundsReceivedAndExecuted(opts *bind.FilterOpts, account []common.Address) (*AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedAndExecutedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossReceiveFundsAndExecuteGateway.contract.FilterLogs(opts, "AcrossFundsReceivedAndExecuted", accountRule)
	if err != nil {
		return nil, err
	}
	return &AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedAndExecutedIterator{contract: _AcrossReceiveFundsAndExecuteGateway.contract, event: "AcrossFundsReceivedAndExecuted", logs: logs, sub: sub}, nil
}

// WatchAcrossFundsReceivedAndExecuted is a free log subscription operation binding the contract event 0xd88a3ae4799f4e1c36d5e250d49c982bbcdc83d4ef55ed7fbfda5b201759e65f.
//
// Solidity: event AcrossFundsReceivedAndExecuted(address indexed account)
func (_AcrossReceiveFundsAndExecuteGateway *AcrossReceiveFundsAndExecuteGatewayFilterer) WatchAcrossFundsReceivedAndExecuted(opts *bind.WatchOpts, sink chan<- *AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedAndExecuted, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossReceiveFundsAndExecuteGateway.contract.WatchLogs(opts, "AcrossFundsReceivedAndExecuted", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedAndExecuted)
				if err := _AcrossReceiveFundsAndExecuteGateway.contract.UnpackLog(event, "AcrossFundsReceivedAndExecuted", log); err != nil {
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
func (_AcrossReceiveFundsAndExecuteGateway *AcrossReceiveFundsAndExecuteGatewayFilterer) ParseAcrossFundsReceivedAndExecuted(log types.Log) (*AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedAndExecuted, error) {
	event := new(AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedAndExecuted)
	if err := _AcrossReceiveFundsAndExecuteGateway.contract.UnpackLog(event, "AcrossFundsReceivedAndExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedButNotEnoughBalanceIterator is returned from FilterAcrossFundsReceivedButNotEnoughBalance and is used to iterate over the raw logs and unpacked data for AcrossFundsReceivedButNotEnoughBalance events raised by the AcrossReceiveFundsAndExecuteGateway contract.
type AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedButNotEnoughBalanceIterator struct {
	Event *AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedButNotEnoughBalance // Event containing the contract specifics and raw log

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
func (it *AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedButNotEnoughBalanceIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedButNotEnoughBalance)
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
		it.Event = new(AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedButNotEnoughBalance)
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
func (it *AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedButNotEnoughBalanceIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedButNotEnoughBalanceIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedButNotEnoughBalance represents a AcrossFundsReceivedButNotEnoughBalance event raised by the AcrossReceiveFundsAndExecuteGateway contract.
type AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedButNotEnoughBalance struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAcrossFundsReceivedButNotEnoughBalance is a free log retrieval operation binding the contract event 0xb86165879c164ced5021b2b5c5c559281e991c7171a39df5b2699f900a9f3ebe.
//
// Solidity: event AcrossFundsReceivedButNotEnoughBalance(address indexed account)
func (_AcrossReceiveFundsAndExecuteGateway *AcrossReceiveFundsAndExecuteGatewayFilterer) FilterAcrossFundsReceivedButNotEnoughBalance(opts *bind.FilterOpts, account []common.Address) (*AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedButNotEnoughBalanceIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossReceiveFundsAndExecuteGateway.contract.FilterLogs(opts, "AcrossFundsReceivedButNotEnoughBalance", accountRule)
	if err != nil {
		return nil, err
	}
	return &AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedButNotEnoughBalanceIterator{contract: _AcrossReceiveFundsAndExecuteGateway.contract, event: "AcrossFundsReceivedButNotEnoughBalance", logs: logs, sub: sub}, nil
}

// WatchAcrossFundsReceivedButNotEnoughBalance is a free log subscription operation binding the contract event 0xb86165879c164ced5021b2b5c5c559281e991c7171a39df5b2699f900a9f3ebe.
//
// Solidity: event AcrossFundsReceivedButNotEnoughBalance(address indexed account)
func (_AcrossReceiveFundsAndExecuteGateway *AcrossReceiveFundsAndExecuteGatewayFilterer) WatchAcrossFundsReceivedButNotEnoughBalance(opts *bind.WatchOpts, sink chan<- *AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedButNotEnoughBalance, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossReceiveFundsAndExecuteGateway.contract.WatchLogs(opts, "AcrossFundsReceivedButNotEnoughBalance", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedButNotEnoughBalance)
				if err := _AcrossReceiveFundsAndExecuteGateway.contract.UnpackLog(event, "AcrossFundsReceivedButNotEnoughBalance", log); err != nil {
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
func (_AcrossReceiveFundsAndExecuteGateway *AcrossReceiveFundsAndExecuteGatewayFilterer) ParseAcrossFundsReceivedButNotEnoughBalance(log types.Log) (*AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedButNotEnoughBalance, error) {
	event := new(AcrossReceiveFundsAndExecuteGatewayAcrossFundsReceivedButNotEnoughBalance)
	if err := _AcrossReceiveFundsAndExecuteGateway.contract.UnpackLog(event, "AcrossFundsReceivedButNotEnoughBalance", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
