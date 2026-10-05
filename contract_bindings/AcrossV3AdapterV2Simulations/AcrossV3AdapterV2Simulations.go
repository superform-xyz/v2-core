// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package AcrossV3AdapterV2Simulations

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

// AcrossV3AdapterV2SimulationsMetaData contains all meta data concerning the AcrossV3AdapterV2Simulations contract.
var AcrossV3AdapterV2SimulationsMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"acrossSpokePool_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"superDestinationExecutor_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"ACROSS_SPOKE_POOL\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_DESTINATION_EXECUTOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISuperDestinationExecutor\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"SUPER_DESTINATION_VALIDATOR\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"handleV3AcrossMessage\",\"inputs\":[{\"name\":\"tokenSent\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"message\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"AcrossFundsReceivedAndExecuted\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AcrossFundsReceivedButExecutionFailed\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AcrossFundsReceivedButNotEnoughBalance\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransferSucceeded\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCOUNT_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ADDRESS_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"DESTINATION_EXECUTION_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EXECUTOR_NOT_VALID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_SENDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NO_DST_PROOF_FOR_CHAIN\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"VALIDATOR_NOT_VALID\",\"inputs\":[]}]",
}

// AcrossV3AdapterV2SimulationsABI is the input ABI used to generate the binding from.
// Deprecated: Use AcrossV3AdapterV2SimulationsMetaData.ABI instead.
var AcrossV3AdapterV2SimulationsABI = AcrossV3AdapterV2SimulationsMetaData.ABI

// AcrossV3AdapterV2Simulations is an auto generated Go binding around an Ethereum contract.
type AcrossV3AdapterV2Simulations struct {
	AcrossV3AdapterV2SimulationsCaller     // Read-only binding to the contract
	AcrossV3AdapterV2SimulationsTransactor // Write-only binding to the contract
	AcrossV3AdapterV2SimulationsFilterer   // Log filterer for contract events
}

// AcrossV3AdapterV2SimulationsCaller is an auto generated read-only Go binding around an Ethereum contract.
type AcrossV3AdapterV2SimulationsCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AcrossV3AdapterV2SimulationsTransactor is an auto generated write-only Go binding around an Ethereum contract.
type AcrossV3AdapterV2SimulationsTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AcrossV3AdapterV2SimulationsFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type AcrossV3AdapterV2SimulationsFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AcrossV3AdapterV2SimulationsSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type AcrossV3AdapterV2SimulationsSession struct {
	Contract     *AcrossV3AdapterV2Simulations // Generic contract binding to set the session for
	CallOpts     bind.CallOpts                 // Call options to use throughout this session
	TransactOpts bind.TransactOpts             // Transaction auth options to use throughout this session
}

// AcrossV3AdapterV2SimulationsCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type AcrossV3AdapterV2SimulationsCallerSession struct {
	Contract *AcrossV3AdapterV2SimulationsCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                       // Call options to use throughout this session
}

// AcrossV3AdapterV2SimulationsTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type AcrossV3AdapterV2SimulationsTransactorSession struct {
	Contract     *AcrossV3AdapterV2SimulationsTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                       // Transaction auth options to use throughout this session
}

// AcrossV3AdapterV2SimulationsRaw is an auto generated low-level Go binding around an Ethereum contract.
type AcrossV3AdapterV2SimulationsRaw struct {
	Contract *AcrossV3AdapterV2Simulations // Generic contract binding to access the raw methods on
}

// AcrossV3AdapterV2SimulationsCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type AcrossV3AdapterV2SimulationsCallerRaw struct {
	Contract *AcrossV3AdapterV2SimulationsCaller // Generic read-only contract binding to access the raw methods on
}

// AcrossV3AdapterV2SimulationsTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type AcrossV3AdapterV2SimulationsTransactorRaw struct {
	Contract *AcrossV3AdapterV2SimulationsTransactor // Generic write-only contract binding to access the raw methods on
}

// NewAcrossV3AdapterV2Simulations creates a new instance of AcrossV3AdapterV2Simulations, bound to a specific deployed contract.
func NewAcrossV3AdapterV2Simulations(address common.Address, backend bind.ContractBackend) (*AcrossV3AdapterV2Simulations, error) {
	contract, err := bindAcrossV3AdapterV2Simulations(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterV2Simulations{AcrossV3AdapterV2SimulationsCaller: AcrossV3AdapterV2SimulationsCaller{contract: contract}, AcrossV3AdapterV2SimulationsTransactor: AcrossV3AdapterV2SimulationsTransactor{contract: contract}, AcrossV3AdapterV2SimulationsFilterer: AcrossV3AdapterV2SimulationsFilterer{contract: contract}}, nil
}

// NewAcrossV3AdapterV2SimulationsCaller creates a new read-only instance of AcrossV3AdapterV2Simulations, bound to a specific deployed contract.
func NewAcrossV3AdapterV2SimulationsCaller(address common.Address, caller bind.ContractCaller) (*AcrossV3AdapterV2SimulationsCaller, error) {
	contract, err := bindAcrossV3AdapterV2Simulations(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterV2SimulationsCaller{contract: contract}, nil
}

// NewAcrossV3AdapterV2SimulationsTransactor creates a new write-only instance of AcrossV3AdapterV2Simulations, bound to a specific deployed contract.
func NewAcrossV3AdapterV2SimulationsTransactor(address common.Address, transactor bind.ContractTransactor) (*AcrossV3AdapterV2SimulationsTransactor, error) {
	contract, err := bindAcrossV3AdapterV2Simulations(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterV2SimulationsTransactor{contract: contract}, nil
}

// NewAcrossV3AdapterV2SimulationsFilterer creates a new log filterer instance of AcrossV3AdapterV2Simulations, bound to a specific deployed contract.
func NewAcrossV3AdapterV2SimulationsFilterer(address common.Address, filterer bind.ContractFilterer) (*AcrossV3AdapterV2SimulationsFilterer, error) {
	contract, err := bindAcrossV3AdapterV2Simulations(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterV2SimulationsFilterer{contract: contract}, nil
}

// bindAcrossV3AdapterV2Simulations binds a generic wrapper to an already deployed contract.
func bindAcrossV3AdapterV2Simulations(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := AcrossV3AdapterV2SimulationsMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _AcrossV3AdapterV2Simulations.Contract.AcrossV3AdapterV2SimulationsCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossV3AdapterV2Simulations.Contract.AcrossV3AdapterV2SimulationsTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _AcrossV3AdapterV2Simulations.Contract.AcrossV3AdapterV2SimulationsTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _AcrossV3AdapterV2Simulations.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AcrossV3AdapterV2Simulations.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _AcrossV3AdapterV2Simulations.Contract.contract.Transact(opts, method, params...)
}

// ACROSSSPOKEPOOL is a free data retrieval call binding the contract method 0xd72b1de1.
//
// Solidity: function ACROSS_SPOKE_POOL() view returns(address)
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsCaller) ACROSSSPOKEPOOL(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterV2Simulations.contract.Call(opts, &out, "ACROSS_SPOKE_POOL")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// ACROSSSPOKEPOOL is a free data retrieval call binding the contract method 0xd72b1de1.
//
// Solidity: function ACROSS_SPOKE_POOL() view returns(address)
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsSession) ACROSSSPOKEPOOL() (common.Address, error) {
	return _AcrossV3AdapterV2Simulations.Contract.ACROSSSPOKEPOOL(&_AcrossV3AdapterV2Simulations.CallOpts)
}

// ACROSSSPOKEPOOL is a free data retrieval call binding the contract method 0xd72b1de1.
//
// Solidity: function ACROSS_SPOKE_POOL() view returns(address)
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsCallerSession) ACROSSSPOKEPOOL() (common.Address, error) {
	return _AcrossV3AdapterV2Simulations.Contract.ACROSSSPOKEPOOL(&_AcrossV3AdapterV2Simulations.CallOpts)
}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsCaller) SUPERDESTINATIONEXECUTOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterV2Simulations.contract.Call(opts, &out, "SUPER_DESTINATION_EXECUTOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsSession) SUPERDESTINATIONEXECUTOR() (common.Address, error) {
	return _AcrossV3AdapterV2Simulations.Contract.SUPERDESTINATIONEXECUTOR(&_AcrossV3AdapterV2Simulations.CallOpts)
}

// SUPERDESTINATIONEXECUTOR is a free data retrieval call binding the contract method 0xf2ad8247.
//
// Solidity: function SUPER_DESTINATION_EXECUTOR() view returns(address)
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsCallerSession) SUPERDESTINATIONEXECUTOR() (common.Address, error) {
	return _AcrossV3AdapterV2Simulations.Contract.SUPERDESTINATIONEXECUTOR(&_AcrossV3AdapterV2Simulations.CallOpts)
}

// SUPERDESTINATIONVALIDATOR is a free data retrieval call binding the contract method 0x5a0ed186.
//
// Solidity: function SUPER_DESTINATION_VALIDATOR() view returns(address)
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsCaller) SUPERDESTINATIONVALIDATOR(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AcrossV3AdapterV2Simulations.contract.Call(opts, &out, "SUPER_DESTINATION_VALIDATOR")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SUPERDESTINATIONVALIDATOR is a free data retrieval call binding the contract method 0x5a0ed186.
//
// Solidity: function SUPER_DESTINATION_VALIDATOR() view returns(address)
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsSession) SUPERDESTINATIONVALIDATOR() (common.Address, error) {
	return _AcrossV3AdapterV2Simulations.Contract.SUPERDESTINATIONVALIDATOR(&_AcrossV3AdapterV2Simulations.CallOpts)
}

// SUPERDESTINATIONVALIDATOR is a free data retrieval call binding the contract method 0x5a0ed186.
//
// Solidity: function SUPER_DESTINATION_VALIDATOR() view returns(address)
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsCallerSession) SUPERDESTINATIONVALIDATOR() (common.Address, error) {
	return _AcrossV3AdapterV2Simulations.Contract.SUPERDESTINATIONVALIDATOR(&_AcrossV3AdapterV2Simulations.CallOpts)
}

// HandleV3AcrossMessage is a paid mutator transaction binding the contract method 0x3a5be8cb.
//
// Solidity: function handleV3AcrossMessage(address tokenSent, uint256 amount, address , bytes message) returns()
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsTransactor) HandleV3AcrossMessage(opts *bind.TransactOpts, tokenSent common.Address, amount *big.Int, arg2 common.Address, message []byte) (*types.Transaction, error) {
	return _AcrossV3AdapterV2Simulations.contract.Transact(opts, "handleV3AcrossMessage", tokenSent, amount, arg2, message)
}

// HandleV3AcrossMessage is a paid mutator transaction binding the contract method 0x3a5be8cb.
//
// Solidity: function handleV3AcrossMessage(address tokenSent, uint256 amount, address , bytes message) returns()
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsSession) HandleV3AcrossMessage(tokenSent common.Address, amount *big.Int, arg2 common.Address, message []byte) (*types.Transaction, error) {
	return _AcrossV3AdapterV2Simulations.Contract.HandleV3AcrossMessage(&_AcrossV3AdapterV2Simulations.TransactOpts, tokenSent, amount, arg2, message)
}

// HandleV3AcrossMessage is a paid mutator transaction binding the contract method 0x3a5be8cb.
//
// Solidity: function handleV3AcrossMessage(address tokenSent, uint256 amount, address , bytes message) returns()
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsTransactorSession) HandleV3AcrossMessage(tokenSent common.Address, amount *big.Int, arg2 common.Address, message []byte) (*types.Transaction, error) {
	return _AcrossV3AdapterV2Simulations.Contract.HandleV3AcrossMessage(&_AcrossV3AdapterV2Simulations.TransactOpts, tokenSent, amount, arg2, message)
}

// AcrossV3AdapterV2SimulationsAcrossFundsReceivedAndExecutedIterator is returned from FilterAcrossFundsReceivedAndExecuted and is used to iterate over the raw logs and unpacked data for AcrossFundsReceivedAndExecuted events raised by the AcrossV3AdapterV2Simulations contract.
type AcrossV3AdapterV2SimulationsAcrossFundsReceivedAndExecutedIterator struct {
	Event *AcrossV3AdapterV2SimulationsAcrossFundsReceivedAndExecuted // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterV2SimulationsAcrossFundsReceivedAndExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterV2SimulationsAcrossFundsReceivedAndExecuted)
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
		it.Event = new(AcrossV3AdapterV2SimulationsAcrossFundsReceivedAndExecuted)
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
func (it *AcrossV3AdapterV2SimulationsAcrossFundsReceivedAndExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterV2SimulationsAcrossFundsReceivedAndExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterV2SimulationsAcrossFundsReceivedAndExecuted represents a AcrossFundsReceivedAndExecuted event raised by the AcrossV3AdapterV2Simulations contract.
type AcrossV3AdapterV2SimulationsAcrossFundsReceivedAndExecuted struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAcrossFundsReceivedAndExecuted is a free log retrieval operation binding the contract event 0xd88a3ae4799f4e1c36d5e250d49c982bbcdc83d4ef55ed7fbfda5b201759e65f.
//
// Solidity: event AcrossFundsReceivedAndExecuted(address indexed account)
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsFilterer) FilterAcrossFundsReceivedAndExecuted(opts *bind.FilterOpts, account []common.Address) (*AcrossV3AdapterV2SimulationsAcrossFundsReceivedAndExecutedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossV3AdapterV2Simulations.contract.FilterLogs(opts, "AcrossFundsReceivedAndExecuted", accountRule)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterV2SimulationsAcrossFundsReceivedAndExecutedIterator{contract: _AcrossV3AdapterV2Simulations.contract, event: "AcrossFundsReceivedAndExecuted", logs: logs, sub: sub}, nil
}

// WatchAcrossFundsReceivedAndExecuted is a free log subscription operation binding the contract event 0xd88a3ae4799f4e1c36d5e250d49c982bbcdc83d4ef55ed7fbfda5b201759e65f.
//
// Solidity: event AcrossFundsReceivedAndExecuted(address indexed account)
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsFilterer) WatchAcrossFundsReceivedAndExecuted(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterV2SimulationsAcrossFundsReceivedAndExecuted, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossV3AdapterV2Simulations.contract.WatchLogs(opts, "AcrossFundsReceivedAndExecuted", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterV2SimulationsAcrossFundsReceivedAndExecuted)
				if err := _AcrossV3AdapterV2Simulations.contract.UnpackLog(event, "AcrossFundsReceivedAndExecuted", log); err != nil {
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
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsFilterer) ParseAcrossFundsReceivedAndExecuted(log types.Log) (*AcrossV3AdapterV2SimulationsAcrossFundsReceivedAndExecuted, error) {
	event := new(AcrossV3AdapterV2SimulationsAcrossFundsReceivedAndExecuted)
	if err := _AcrossV3AdapterV2Simulations.contract.UnpackLog(event, "AcrossFundsReceivedAndExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterV2SimulationsAcrossFundsReceivedButExecutionFailedIterator is returned from FilterAcrossFundsReceivedButExecutionFailed and is used to iterate over the raw logs and unpacked data for AcrossFundsReceivedButExecutionFailed events raised by the AcrossV3AdapterV2Simulations contract.
type AcrossV3AdapterV2SimulationsAcrossFundsReceivedButExecutionFailedIterator struct {
	Event *AcrossV3AdapterV2SimulationsAcrossFundsReceivedButExecutionFailed // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterV2SimulationsAcrossFundsReceivedButExecutionFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterV2SimulationsAcrossFundsReceivedButExecutionFailed)
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
		it.Event = new(AcrossV3AdapterV2SimulationsAcrossFundsReceivedButExecutionFailed)
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
func (it *AcrossV3AdapterV2SimulationsAcrossFundsReceivedButExecutionFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterV2SimulationsAcrossFundsReceivedButExecutionFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterV2SimulationsAcrossFundsReceivedButExecutionFailed represents a AcrossFundsReceivedButExecutionFailed event raised by the AcrossV3AdapterV2Simulations contract.
type AcrossV3AdapterV2SimulationsAcrossFundsReceivedButExecutionFailed struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAcrossFundsReceivedButExecutionFailed is a free log retrieval operation binding the contract event 0x04c138373117f58fea06058b5a537a58b5a5324f226667d219560baa728b609a.
//
// Solidity: event AcrossFundsReceivedButExecutionFailed(address indexed account)
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsFilterer) FilterAcrossFundsReceivedButExecutionFailed(opts *bind.FilterOpts, account []common.Address) (*AcrossV3AdapterV2SimulationsAcrossFundsReceivedButExecutionFailedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossV3AdapterV2Simulations.contract.FilterLogs(opts, "AcrossFundsReceivedButExecutionFailed", accountRule)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterV2SimulationsAcrossFundsReceivedButExecutionFailedIterator{contract: _AcrossV3AdapterV2Simulations.contract, event: "AcrossFundsReceivedButExecutionFailed", logs: logs, sub: sub}, nil
}

// WatchAcrossFundsReceivedButExecutionFailed is a free log subscription operation binding the contract event 0x04c138373117f58fea06058b5a537a58b5a5324f226667d219560baa728b609a.
//
// Solidity: event AcrossFundsReceivedButExecutionFailed(address indexed account)
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsFilterer) WatchAcrossFundsReceivedButExecutionFailed(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterV2SimulationsAcrossFundsReceivedButExecutionFailed, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossV3AdapterV2Simulations.contract.WatchLogs(opts, "AcrossFundsReceivedButExecutionFailed", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterV2SimulationsAcrossFundsReceivedButExecutionFailed)
				if err := _AcrossV3AdapterV2Simulations.contract.UnpackLog(event, "AcrossFundsReceivedButExecutionFailed", log); err != nil {
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
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsFilterer) ParseAcrossFundsReceivedButExecutionFailed(log types.Log) (*AcrossV3AdapterV2SimulationsAcrossFundsReceivedButExecutionFailed, error) {
	event := new(AcrossV3AdapterV2SimulationsAcrossFundsReceivedButExecutionFailed)
	if err := _AcrossV3AdapterV2Simulations.contract.UnpackLog(event, "AcrossFundsReceivedButExecutionFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterV2SimulationsAcrossFundsReceivedButNotEnoughBalanceIterator is returned from FilterAcrossFundsReceivedButNotEnoughBalance and is used to iterate over the raw logs and unpacked data for AcrossFundsReceivedButNotEnoughBalance events raised by the AcrossV3AdapterV2Simulations contract.
type AcrossV3AdapterV2SimulationsAcrossFundsReceivedButNotEnoughBalanceIterator struct {
	Event *AcrossV3AdapterV2SimulationsAcrossFundsReceivedButNotEnoughBalance // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterV2SimulationsAcrossFundsReceivedButNotEnoughBalanceIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterV2SimulationsAcrossFundsReceivedButNotEnoughBalance)
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
		it.Event = new(AcrossV3AdapterV2SimulationsAcrossFundsReceivedButNotEnoughBalance)
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
func (it *AcrossV3AdapterV2SimulationsAcrossFundsReceivedButNotEnoughBalanceIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterV2SimulationsAcrossFundsReceivedButNotEnoughBalanceIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterV2SimulationsAcrossFundsReceivedButNotEnoughBalance represents a AcrossFundsReceivedButNotEnoughBalance event raised by the AcrossV3AdapterV2Simulations contract.
type AcrossV3AdapterV2SimulationsAcrossFundsReceivedButNotEnoughBalance struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterAcrossFundsReceivedButNotEnoughBalance is a free log retrieval operation binding the contract event 0xb86165879c164ced5021b2b5c5c559281e991c7171a39df5b2699f900a9f3ebe.
//
// Solidity: event AcrossFundsReceivedButNotEnoughBalance(address indexed account)
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsFilterer) FilterAcrossFundsReceivedButNotEnoughBalance(opts *bind.FilterOpts, account []common.Address) (*AcrossV3AdapterV2SimulationsAcrossFundsReceivedButNotEnoughBalanceIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossV3AdapterV2Simulations.contract.FilterLogs(opts, "AcrossFundsReceivedButNotEnoughBalance", accountRule)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterV2SimulationsAcrossFundsReceivedButNotEnoughBalanceIterator{contract: _AcrossV3AdapterV2Simulations.contract, event: "AcrossFundsReceivedButNotEnoughBalance", logs: logs, sub: sub}, nil
}

// WatchAcrossFundsReceivedButNotEnoughBalance is a free log subscription operation binding the contract event 0xb86165879c164ced5021b2b5c5c559281e991c7171a39df5b2699f900a9f3ebe.
//
// Solidity: event AcrossFundsReceivedButNotEnoughBalance(address indexed account)
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsFilterer) WatchAcrossFundsReceivedButNotEnoughBalance(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterV2SimulationsAcrossFundsReceivedButNotEnoughBalance, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _AcrossV3AdapterV2Simulations.contract.WatchLogs(opts, "AcrossFundsReceivedButNotEnoughBalance", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterV2SimulationsAcrossFundsReceivedButNotEnoughBalance)
				if err := _AcrossV3AdapterV2Simulations.contract.UnpackLog(event, "AcrossFundsReceivedButNotEnoughBalance", log); err != nil {
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
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsFilterer) ParseAcrossFundsReceivedButNotEnoughBalance(log types.Log) (*AcrossV3AdapterV2SimulationsAcrossFundsReceivedButNotEnoughBalance, error) {
	event := new(AcrossV3AdapterV2SimulationsAcrossFundsReceivedButNotEnoughBalance)
	if err := _AcrossV3AdapterV2Simulations.contract.UnpackLog(event, "AcrossFundsReceivedButNotEnoughBalance", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AcrossV3AdapterV2SimulationsTransferSucceededIterator is returned from FilterTransferSucceeded and is used to iterate over the raw logs and unpacked data for TransferSucceeded events raised by the AcrossV3AdapterV2Simulations contract.
type AcrossV3AdapterV2SimulationsTransferSucceededIterator struct {
	Event *AcrossV3AdapterV2SimulationsTransferSucceeded // Event containing the contract specifics and raw log

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
func (it *AcrossV3AdapterV2SimulationsTransferSucceededIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AcrossV3AdapterV2SimulationsTransferSucceeded)
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
		it.Event = new(AcrossV3AdapterV2SimulationsTransferSucceeded)
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
func (it *AcrossV3AdapterV2SimulationsTransferSucceededIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AcrossV3AdapterV2SimulationsTransferSucceededIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AcrossV3AdapterV2SimulationsTransferSucceeded represents a TransferSucceeded event raised by the AcrossV3AdapterV2Simulations contract.
type AcrossV3AdapterV2SimulationsTransferSucceeded struct {
	Account common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterTransferSucceeded is a free log retrieval operation binding the contract event 0xb4f875d925805b35ef8df5a5cfb3e81cd4cff682cdc8ac555507c51508525259.
//
// Solidity: event TransferSucceeded(address indexed account, address indexed token, uint256 amount)
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsFilterer) FilterTransferSucceeded(opts *bind.FilterOpts, account []common.Address, token []common.Address) (*AcrossV3AdapterV2SimulationsTransferSucceededIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _AcrossV3AdapterV2Simulations.contract.FilterLogs(opts, "TransferSucceeded", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return &AcrossV3AdapterV2SimulationsTransferSucceededIterator{contract: _AcrossV3AdapterV2Simulations.contract, event: "TransferSucceeded", logs: logs, sub: sub}, nil
}

// WatchTransferSucceeded is a free log subscription operation binding the contract event 0xb4f875d925805b35ef8df5a5cfb3e81cd4cff682cdc8ac555507c51508525259.
//
// Solidity: event TransferSucceeded(address indexed account, address indexed token, uint256 amount)
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsFilterer) WatchTransferSucceeded(opts *bind.WatchOpts, sink chan<- *AcrossV3AdapterV2SimulationsTransferSucceeded, account []common.Address, token []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _AcrossV3AdapterV2Simulations.contract.WatchLogs(opts, "TransferSucceeded", accountRule, tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AcrossV3AdapterV2SimulationsTransferSucceeded)
				if err := _AcrossV3AdapterV2Simulations.contract.UnpackLog(event, "TransferSucceeded", log); err != nil {
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

// ParseTransferSucceeded is a log parse operation binding the contract event 0xb4f875d925805b35ef8df5a5cfb3e81cd4cff682cdc8ac555507c51508525259.
//
// Solidity: event TransferSucceeded(address indexed account, address indexed token, uint256 amount)
func (_AcrossV3AdapterV2Simulations *AcrossV3AdapterV2SimulationsFilterer) ParseTransferSucceeded(log types.Log) (*AcrossV3AdapterV2SimulationsTransferSucceeded, error) {
	event := new(AcrossV3AdapterV2SimulationsTransferSucceeded)
	if err := _AcrossV3AdapterV2Simulations.contract.UnpackLog(event, "TransferSucceeded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
